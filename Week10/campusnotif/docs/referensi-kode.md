# Referensi kode

Kontrak setiap berkas di `lib/` dan `test/` setelah restrukturisasi
**layer-first (data · domain · presentation)**. Untuk alur dan alasan desain,
lihat [`arsitektur.md`](arsitektur.md).

## Cara membaca dokumen ini

- **Tanda tangan** ditulis seperti di kode, tanpa `import`.
- **Invarian** adalah aturan yang tidak boleh dilanggar saat mengubah berkas.
- **Dikunci oleh** menyebut test yang akan gagal bila perilaku berubah.
- Urutan bagian mengikuti arah dependensi: `domain` → `data` → `presentation`.

## Ringkasan lapisan

| Lapisan | Folder | Isi | Boleh meng-import |
|---|---|---|---|
| Domain | `lib/domain/` | entity, error, kontrak repository, use case, rute, masking | hanya `dart:` |
| Data | `lib/data/` | implementasi kontrak: Firebase, Dio, secure storage, prefs, FCM, plugin badge | `dart:`, paket, `domain/` |
| Presentation | `lib/presentation/` | controller Riverpod, composition root, router, halaman, format tampilan | `flutter`, `flutter_riverpod`, `go_router`, `domain/` |
| Bootstrap | `lib/main.dart` | `bootstrapFirebase()` → `ProviderScope` → `MaterialApp.router` | semua lapisan |

Aturan keras yang dijaga: `domain/` tidak meng-import Flutter/Firebase/Dio, dan
`presentation/` tidak meng-import SDK apa pun (tidak ada `firebase_messaging`,
`firebase_auth`, `flutter_secure_storage`, atau `dio` di sana).

## 1. `lib/domain/`

### 1.1 `routes.dart`

```dart
abstract final class Routes {
  static const String login = '/login';
  static const String home = '/';
  static const String notifications = '/notifikasi';
  static const String announcementPattern = '/pengumuman/:id';
  static const String announcementIdParam = 'id';
  static String announcement(String id);
  static String sanitize(String? route);
}
```

| Aspek | Isi |
|---|---|
| Kenapa di domain | Rute adalah kontrak: notifikasi membawa rute, router membukanya. Menaruhnya di presentation akan memaksa lapisan data meng-import UI |
| `sanitize` | `null`/kosong → `/`; garis miring di depan ditambahkan bila hilang; spasi tepi dibuang |

**Dikunci oleh:** grup `Routes.sanitize` dan `routeFromMessage` di
`test/payload_test.dart`.

### 1.2 `constants.dart`

```dart
const String kCampusTopic = 'pengumuman-kampus';
```

Topik broadcast untuk seluruh mahasiswa. Aturan "semua mahasiswa menerima
pengumuman" milik domain; nama topik hanyalah detail pengiriman.

### 1.3 `entities/app_notification.dart`

```dart
class AppNotification {
  const AppNotification({required id, required title, required body,
                         required route, required receivedAt});
  factory AppNotification.create({String? messageId, required String title,
                                 required String body, required String route,
                                 DateTime? receivedAt});
  static const String fallbackTitle = 'Pengumuman';
  final String id, title, body, route;
  final DateTime receivedAt;
}
```

| Invarian | Alasan |
|---|---|
| `id` = `messageId` bila ada, jika tidak `<microsecondsSinceEpoch>-<route>` | Pesan yang dikirim ulang FCM tidak tercatat dua kali |
| Judul kosong → `fallbackTitle` | Baris daftar tidak pernah kosong |
| `title`/`body` di-`trim()` | Spasi dari payload tidak ikut tampil |

Entity ini **tidak** punya `toJson`/`fromJson`: serialisasi ada di lapisan data.

**Dikunci oleh:** grup `AppNotification` di `test/notification_test.dart`.

### 1.4 `entities/auth_session.dart`

```dart
class AuthSession {
  const AuthSession({required String access, required String refresh, String? email});
  final String access, refresh;
  final String? email;
  String get maskedAccess;                       // maskSecret(access)
  AuthSession copyWith({String? access, String? refresh, String? email});
}
```

**Invarian:** `maskedAccess` adalah satu-satunya bentuk token yang boleh
dirender. `copyWith` dipakai `RefreshSessionUseCase` untuk mengganti `access`
tanpa menyentuh `refresh`/`email`.

**Dikunci oleh:** `AuthSession.maskedAccess tidak membocorkan token utuh`
(`test/auth_test.dart`), `maskSecret` (`test/payload_test.dart`).

### 1.5 `entities/notification_inbox.dart`

```dart
abstract final class NotificationInbox {
  static const int maxEntries = 50;
  static List<AppNotification> withAdded(List<AppNotification> current, AppNotification item);
  static List<AppNotification> without(List<AppNotification> current, String id);
}
```

Fungsi murni: entri baru di urutan teratas, id sama diganti (bukan duplikat),
panjang dipotong ke `maxEntries`. Karena murni, aturan ini bisa diuji tanpa
penyimpanan — dan berlaku untuk penyimpanan apa pun.

**Dikunci oleh:** grup `NotificationInbox` (4 test) di `test/notification_test.dart`.

### 1.6 `entities/push_registration.dart`

```dart
class PushRegistration {
  PushRegistration({required String? token, required bool permissionGranted,
                    required bool registeredOnBackend, required Future<void> Function() onStop});
  Future<void> stop();      // idempoten
}
```

Pemegang langganan stream FCM. Satu pemilik untuk pemasangan **dan** pelepasan;
`stop()` aman dipanggil dua kali.

**Dikunci oleh:** `PushController` grup di `test/push_test.dart` (detach
menghentikan langganan topik dan pesan tidak lagi dicatat).

### 1.7 `errors/auth_exception.dart`

```dart
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}
```

Satu-satunya error autentikasi yang boleh naik ke UI. Kode mentah penyedia auth
diterjemahkan lebih dulu di lapisan data (`firebase_auth_messages.dart`).

### 1.8 `repositories/` — kontrak

| Berkas | Tanda tangan | Implementasi di `data/` |
|---|---|---|
| `auth_repository.dart` | `login({email, password}) → AuthSession`; `refresh(String) → String`; `signOut()` | `FirebaseAuthRepository`, `MockAuthRepository` |
| `session_repository.dart` | `read() → AuthSession?`; `save(AuthSession)`; `clear()` | `SecureSessionRepository` |
| `device_repository.dart` | `register({required String token}) → bool`; `unregister({required String token}) → bool` | `HttpDeviceRepository` |
| `notification_inbox_repository.dart` | `readAll() → List<AppNotification>`; `writeAll(List<AppNotification>)` | `SharedPrefsInboxRepository` |
| `app_badge.dart` | `setCount(int count)` | `LauncherBadge` |
| `push_messaging.dart` | `prepare()`, `requestPermission()`, `currentToken()`, `tokenRefresh`, `foregroundMessages`, `openedMessages`, `bannerTaps`, `initialMessage()`, `subscribeTopic()`, `unsubscribeTopic()`, `showBanner()` | `FcmPushMessaging` |

Invarian kontrak:

| Kontrak | Invarian | Alasan |
|---|---|---|
| `AuthRepository` | `signOut` ada **di dalam** interface, bukan interface tambahan yang diperiksa `is` | Setiap implementasi benar-benar bisa saling menggantikan (LSP); `MockAuthRepository.signOut` no-op |
| `SessionRepository` | `read()` mengembalikan sesi apa adanya, termasuk yang tidak lengkap | Yang menilai "sesi rusak" adalah `RestoreSessionUseCase`, bukan penyimpanan |
| `DeviceRepository` | Nama platform **tidak** menjadi parameter | Deteksi platform adalah kemampuan lapisan data (`platform_name.dart`) |
| `NotificationInboxRepository` | Hanya `readAll`/`writeAll`; tanpa aturan dedupe/batas | Aturan bisnis di `NotificationInbox`; penyimpanan bisa diganti tanpa menyentuh domain |
| `PushMessaging` | Hanya memakai istilah domain (`AppNotification`, `String` rute/token) | `presentation/` tidak pernah meng-import `firebase_messaging` |

**Dikunci oleh:** `test/api_client_test.dart` (kontrak sesi + auth),
`test/push_test.dart` (kontrak device + push messaging),
`test/notification_test.dart` (kontrak kotak masuk).

### 1.9 `usecases/` — satu kelas, satu aksi bisnis

| Use case | Masukan → Keluaran | Invarian |
|---|---|---|
| `auth/LoginUseCase` | `(email, password) → AuthSession` | Login **lalu** simpan; UI tidak perlu tahu urutannya |
| `auth/RestoreSessionUseCase` | `() → AuthSession?` | Sesi setengah jadi (access ada, refresh kosong) dibersihkan lalu `null` |
| `auth/RefreshSessionUseCase` | `() → AuthSession` | Hanya `access` yang diganti; `refresh`/`email` dipertahankan; gagal → `AuthException` |
| `auth/LogoutUseCase` | `() → void` | Urutan: `unregister` → `unsubscribeTopic` → `signOut` → `clear`. `DELETE /devices` butuh header Authorization dari sesi yang masih ada |
| `notifications/LoadInboxUseCase` | `() → List<AppNotification>` | Membaca ulang penyimpanan lalu menyelaraskan badge |
| `notifications/AddNotificationUseCase` | `(AppNotification) → List<AppNotification>` | Memakai `NotificationInbox.withAdded` (dedupe + batas) lalu simpan + badge |
| `notifications/MarkNotificationReadUseCase` | `(String id) → List<AppNotification>` | Entri hilang dari daftar = sudah dibaca |
| `notifications/MarkAllNotificationsReadUseCase` | `() → List<AppNotification>` | `writeAll([])` + badge 0 |
| `notifications/SyncBadgeUseCase` | `(int unread) → void` | Angka negatif dijadikan 0; kegagalan platform ditelan |
| `push/StartPushUseCase` | `({onRoute, onNotification, onOpened}) → PushRegistration` | `prepare()` **sebelum** pesan pertama (kanal immutable); token dilaporkan ke backend; token refresh dilaporkan ulang; listener dikembalikan sebagai satu paket |
| `push/SendTestNotificationUseCase` | `() → void` | Membuat entri demo → catat ke kotak masuk → tampilkan banner |
| `push/SetTopicSubscriptionUseCase` | `({required bool subscribe}) → void` | Satu jalur untuk berlangganan/berhenti |

**Dikunci oleh:** `test/auth_test.dart` (login, restore, refresh),
`test/notification_test.dart` (add/markRead/markAllRead + badge),
`test/push_test.dart` (start/detach/token refresh).

### 1.10 `utils/masking.dart`

```dart
String maskSecret(String value);
```

Nilai ≤ 12 karakter → `••••••`; selain itu 8 karakter awal + `••••` + 4 karakter
akhir. **Dikunci oleh:** grup `maskSecret` di `test/payload_test.dart`.

## 2. `lib/data/`

### 2.1 `datasources/key_value_store.dart`

```dart
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}
class PrefsKeyValueStore implements KeyValueStore   // SharedPreferencesAsync
class InMemoryKeyValueStore implements KeyValueStore // dipakai test
```

Abstraksi ini membuat `SharedPrefsInboxRepository` bisa diuji tanpa platform
channel. **Dikunci oleh:** seluruh grup `SharedPrefsInboxRepository` dan
`NotificationController` di `test/notification_test.dart`.

### 2.2 `mappers/app_notification_mapper.dart`

```dart
Map<String, dynamic> appNotificationToJson(AppNotification notification);
AppNotification? appNotificationFromJson(Map<String, dynamic> json);
```

Kunci JSON: `id`, `title`, `body`, `route`, `received_at` (ISO-8601).
`fromJson` mengembalikan `null` untuk entri rusak (tanpa `id`/`route`), sehingga
satu entri korup tidak menghapus seluruh kotak masuk.

**Dikunci oleh:** `serialisasi bolak-balik mempertahankan isi` dan
`satu entri korup dilewati` di `test/notification_test.dart`.

### 2.3 `messaging/fcm_mapper.dart`

```dart
String routeFromMessage(Map<String, dynamic> data);
String? idFromMessage(Map<String, dynamic> data);
AppNotification appNotificationFromMessage(RemoteMessage message);
```

Fungsi murni (kecuali yang terakhir) — bisa diuji tanpa Firebase. Satu-satunya
tempat yang tahu bentuk `RemoteMessage`.

**Dikunci oleh:** grup `routeFromMessage` + `idFromMessage` (7 test) di
`test/payload_test.dart`.

### 2.4 `messaging/fcm_push_messaging.dart`

```dart
const String kNotificationSoundResource = 'campus_notif';
const AndroidNotificationChannel kAnnouncementChannel;   // id: pengumuman_v2

class FcmPushMessaging implements PushMessaging {
  FcmPushMessaging({FirebaseMessaging? messaging, FlutterLocalNotificationsPlugin? local});
}
```

| Invarian | Alasan |
|---|---|
| `_messaging` adalah **getter malas**, bukan field | `FirebaseMessaging.instance` memanggil `Firebase.app()` yang melempar bila Firebase belum diinisialisasi; kelas harus tetap bisa dibuat pada mode tanpa `google-services.json` |
| `prepare()` membuat kanal secara eksplisit | Setelan kanal Android **immutable**; bila dibuat otomatis oleh pesan pertama, suara kustom tidak akan pernah terpasang |
| `initialMessage()` hanya mengembalikan pesan sekali | `getInitialMessage()` mengembalikan pesan yang sama bila dipanggil ulang → deep link terbuka dua kali |
| `tokenRefresh`/`foregroundMessages`/`openedMessages` berupa `Stream` | Pemegang langganan adalah `StartPushUseCase`; pelepasan jadi eksplisit lewat `PushRegistration.stop()` |

### 2.5 `messaging/firebase_bootstrap.dart`

```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message);

class FirebaseBootstrap { const FirebaseBootstrap({required bool ready, String? reason}); }

Future<FirebaseBootstrap> bootstrapFirebase();
```

| Aspek | Isi |
|---|---|
| Handler background | Fungsi top-level (isolate terpisah). Hanya mencatat ke kotak masuk lewat `SharedPrefsInboxRepository` + `NotificationInbox.withAdded`; tidak menyentuh `BuildContext`, Riverpod, atau router |
| `DartPluginRegistrant.ensureInitialized()` | Plugin (`shared_preferences`) butuh registrant di isolate terpisah |
| Kegagalan | Ditangkap dan dilaporkan sebagai `FirebaseBootstrap(ready: false, reason: ...)`, bukan crash |
| Log | Hanya `messageId` dan `runtimeType` error; tidak ada token |

### 2.6 `platform/platform_name.dart`

```dart
String get platformName;   // 'android' | 'ios' | 'web' | ...
```

Dipakai `HttpDeviceRepository` saat mengirim `POST /devices`, sehingga domain
tidak perlu tahu API platform.

### 2.7 `repositories/secure_session_repository.dart`

```dart
class SecureSessionRepository implements SessionRepository {
  SecureSessionRepository({FlutterSecureStorage? storage});
  static const String storageKey...   // access_token, refresh_token, session_email
}
```

Satu-satunya berkas yang menyentuh `flutter_secure_storage`.

**Invarian:** `read()` mengembalikan `null` hanya bila `access` kosong; sesi
tanpa `refresh` dikembalikan dengan `refresh: ''` agar domain yang memutuskan
sesi itu rusak. `clear()` memakai `deleteAll()`.

**Dikunci oleh:** `test/auth_test.dart` (`sesi setengah jadi dibersihkan`),
`test/api_client_test.dart`, `test/notification_test.dart` (lewat
`FakeSessionRepository`).

### 2.8 `repositories/firebase_auth_repository.dart`

```dart
const String kOpaqueRefreshToken = 'firebase:getIdToken';
class FirebaseAuthRepository implements AuthRepository { FirebaseAuthRepository({FirebaseAuth? auth}); }
```

| Metode | Perilaku |
|---|---|
| `login` | `signInWithEmailAndPassword` → `getIdToken()` sebagai `access` → `refreshToken` (atau `kOpaqueRefreshToken` bila platform tidak mengeksposnya) |
| `refresh` | `user.getIdToken(true)`; argumen `refreshToken` hanya penanda karena Firebase menyimpan sesinya sendiri |
| `signOut` | `FirebaseAuth.signOut()` — ada di interface, bukan `is SignOutCapable` |

Semua `FirebaseAuthException` diterjemahkan lewat `authMessageFor()`.

### 2.9 `repositories/mock_auth_repository.dart`

```dart
class MockAuthRepository implements AuthRepository { const MockAuthRepository(); }
```

Demo offline + test: email mengandung `@`, sandi ≥ 6 karakter, token
`mock-access-for-<email>`. `refresh` menolak `mock-refresh-revoked` (dipakai test
"refresh ditolak → sesi dibersihkan"). `signOut` no-op.

### 2.10 `repositories/http_device_repository.dart`

```dart
class HttpDeviceRepository implements DeviceRepository { const HttpDeviceRepository(Dio dio); }
```

| Endpoint | Body | Catatan |
|---|---|---|
| `POST /devices` | `{"fcm_token": ..., "platform": platformName}` | Header Authorization dari interceptor |
| `DELETE /devices` | `{"fcm_token": ...}` | Butuh sesi aktif — karena itu `LogoutUseCase` memanggilnya sebelum `clear()` |

Kegagalan jaringan → `false`, tidak melempar. **Dikunci oleh:**
`FakeDeviceRepository` di `test/push_test.dart`.

### 2.11 `repositories/shared_prefs_inbox_repository.dart`

```dart
class SharedPrefsInboxRepository implements NotificationInboxRepository {
  SharedPrefsInboxRepository({KeyValueStore? store});
  static const String storageKey = 'campus_notif.inbox';
}
```

Menyimpan JSON array di satu kunci. `readAll()` mengembalikan daftar kosong bila
data bukan JSON valid; `writeAll()` menulis seluruh daftar (bukan append), jadi
aturan urutan/dedupe sepenuhnya milik domain.

### 2.12 `repositories/launcher_badge.dart`

```dart
class LauncherBadge implements AppBadge { const LauncherBadge(); }
```

`AppBadgePlus.isSupported()` → bila `false`, berhenti tanpa error. Semua
exception platform ditelan: badge hanya pelengkap.

### 2.13 `http/api_client.dart`

```dart
const String kApiBaseUrl = 'https://example-campus-api.test';
Dio buildApiClient({required SessionRepository sessions, required AuthRepository auth,
                    required Future<void> Function() onSessionExpired, String baseUrl});
```

| Aspek | Isi |
|---|---|
| `onRequest` | Menyisipkan `Authorization: Bearer <access>` bila header belum ada |
| `onError` 401 | Satu kali `auth.refresh()` → `sessions.save(copyWith(access:))` → `dio.fetch()` ulang dengan penanda `extra['auth_retried']` |
| Refresh gagal / tidak ada refresh | `sessions.clear()` + `onSessionExpired()` → error asli diteruskan (tanpa retry berulang) |

**Dikunci oleh:** ketiga test di `test/api_client_test.dart` (2 request saat
sukses, 1 request saat refresh mati).

### 2.14 `errors/api_error_messages.dart`

```dart
String friendlyApiMessage(Object error);
```

`DioException` → kalimat Indonesia (timeout, tanpa koneksi, 401/403/404/5xx,
dll.). UI tidak pernah merender `DioException` mentah.

### 2.15 `errors/firebase_auth_messages.dart`

```dart
String authMessageFor(String code, String? fallback);
```

Pemetaan kode Firebase Auth (`wrong-password`, `invalid-credential`,
`too-many-requests`, …) → kalimat Indonesia. **Dikunci oleh:** grup
`authMessageFor` (3 test) di `test/notification_test.dart`.

## 3. `lib/presentation/`

### 3.1 `providers/dependencies.dart`

Composition root: seluruh provider dependency dan use case.

```dart
final Provider<bool> firebaseReadyProvider;                        // default false
final Provider<KeyValueStore> keyValueStoreProvider;
final Provider<SessionRepository> sessionRepositoryProvider;
final Provider<AuthRepository> authRepositoryProvider;             // Firebase / mock
final Provider<Dio> apiClientProvider;
final Provider<DeviceRepository> deviceRepositoryProvider;
final Provider<PushMessaging> pushMessagingProvider;
final Provider<NotificationInboxRepository> inboxRepositoryProvider;
final Provider<AppBadge> appBadgeProvider;
// 12 provider use case: syncBadge, loadInbox, addNotification,
// markNotificationRead, markAllNotificationsRead, login, restoreSession,
// refreshSession, logout, startPush, sendTestNotification, setTopicSubscription
```

**Invarian:** ini satu-satunya berkas yang menyebut nama kelas konkret dari
`data/`. Menambah implementasi baru cukup menambah/mengganti satu baris di sini.

### 3.2 `providers/app_router.dart`

```dart
final Provider<GoRouter> appRouterProvider;
```

| Aspek | Isi |
|---|---|
| Guard | `auth.isLoading && !auth.hasValue` → `null` (jangan ambil keputusan saat sesi masih dibaca); belum login & bukan `/login` → `/login`; sudah login di `/login` → `/` |
| `refreshListenable` | `_AuthRefresh` menjembatani `ref.listen(authControllerProvider)` ke `ChangeNotifier` |
| Rute | `/login`, `/`, `/notifikasi`, `/pengumuman/:id` (semua dari `Routes`) |

**Invarian:** router dibuat **sekali**; perubahan sesi hanya memicu redirect.

### 3.3 `providers/auth/auth_controller.dart`

```dart
final AsyncNotifierProvider<AuthController, AuthSession?> authControllerProvider;

class AuthController extends AsyncNotifier<AuthSession?> {
  Future<AuthSession?> build();               // RestoreSessionUseCase
  Future<void> login(String email, String password);
  Future<bool> refreshSession();
  Future<void> logout();
  Future<void> forceLogout();
}
```

| Metode | Perilaku |
|---|---|
| `login` | `AsyncLoading` → `AsyncValue.guard(LoginUseCase)` |
| `refreshSession` | Sukses → `AsyncData(sesi baru)`; gagal → `forceLogout()` + `false` |
| `logout` | `LogoutUseCase`; bila jaringan gagal, sesi lokal tetap dibersihkan |
| `forceLogout` | `clear()` + `signOut()` tanpa melempar ke UI (dipakai interceptor) |

**Dikunci oleh:** 5 test di `test/auth_test.dart` (guard route, login, sesi
setengah jadi, refresh sukses/gagal).

### 3.4 `providers/notifications/notification_controller.dart`

```dart
final NotifierProvider<NotificationController, List<AppNotification>> notificationsProvider;

class NotificationController extends Notifier<List<AppNotification>> {
  int get unreadCount;                        // state.length
  Future<void> reload();
  Future<void> add(AppNotification notification);
  Future<void> markRead(String id);
  Future<void> markAllRead();
}
```

| Invarian | Alasan |
|---|---|
| `build()` mengembalikan `[]` lalu memanggil `reload()` lewat microtask | `state` tidak boleh diubah saat build |
| Setiap method memakai `_disposed` guard | Provider bisa dibuang saat operasi async masih berjalan |
| Angka badge tidak disimpan di sini | Satu sumber kebenaran: `state.length` → `SyncBadgeUseCase` |

### 3.5 `providers/push/push_state.dart`

```dart
class PushState {
  const PushState({started, permissionGranted, token, registeredOnBackend,
                   subscribedTopic, lastRoute, note});
  String get maskedToken;
  PushState copyWith({bool? started, bool? permissionGranted, Object? token = _unset,
                      bool? registeredOnBackend, bool? subscribedTopic,
                      Object? lastRoute = _unset, Object? note = _unset});
}
```

**Invarian `copyWith`:** field nullable memakai sentinel `_unset`, sehingga
`copyWith(note: null)` berarti **mengosongkan**, sedangkan parameter yang tidak
disebut mempertahankan nilai lama. Tanpa sentinel, catatan error tidak bisa
dihapus dan `token` tidak bisa dikosongkan saat logout.

**Dikunci oleh:** grup `PushState.copyWith` (5 test) di `test/push_test.dart`.

### 3.6 `providers/push/push_controller.dart`

```dart
final NotifierProvider<PushController, PushState> pushProvider;

class PushController extends Notifier<PushState> {
  Future<void> start({required bool firebaseReady, String? firebaseNote});
  Future<void> detach();
  Future<void> sendTestNotification();
  Future<void> toggleTopic(bool subscribe);
}
```

| Aspek | Isi |
|---|---|
| `start` | `started` true → berhenti (tidak memasang listener ganda); Firebase belum siap → hanya menulis `note`; selebihnya `StartPushUseCase` |
| `note` | Diturunkan dari `PushRegistration`: izin ditolak / `POST /devices` belum tersedia / `null` |
| `detach` | `PushRegistration.stop()` → state direset (`started: false`, `token: null`, `note: null`) supaya `start()` bisa jalan lagi setelah login berikutnya |
| `_go` | `Routes.sanitize` → `lastRoute` → `appRouterProvider.go` (satu-satunya tempat navigasi dari notifikasi) |
| `_openFromNotification` | `markRead(id)` bila ada `messageId`, lalu `_go(route)` |

**Dikunci oleh:** 9 test di `test/push_test.dart` (registrasi, token refresh,
izin ditolak, tanpa Firebase, pesan foreground, detach, start ulang).

### 3.7 `utils/relative_time.dart`

```dart
String relativeTime(DateTime at, {DateTime? now});
```

`baru saja` (< 60 dtk atau waktu masa depan), `N mnt lalu`, `N jam lalu`,
`N hr lalu`, lalu `dd/MM/yyyy`. Parameter `now` membuat test deterministik.
**Dikunci oleh:** grup `relativeTime` (4 test) di `test/notification_test.dart`.

### 3.8 `pages/`

| Berkas | Tanggung jawab | Catatan |
|---|---|---|
| `login_page.dart` | Form email + sandi, validasi lokal, panggil `authControllerProvider.notifier.login` | Tidak memanggil `context.go()`; perpindahan layar hasil guard |
| `home_page.dart` | Kartu sesi (token ter-mask), tombol refresh, kartu status FCM, lonceng + badge, tombol notifikasi uji, logout | Logout: `pushProvider.notifier.detach()` **lalu** `authControllerProvider.notifier.logout()` |
| `notifications_page.dart` | Daftar notifikasi belum dibaca, tarik-untuk-menyegarkan, "tandai semua" | `reload()` saat halaman dibuka karena handler background menulis dari isolate lain |
| `announcement_page.dart` | Target deep link `/pengumuman/:id` (data demo) | Menampilkan `id` dari `pathParameters` |

## 4. `lib/main.dart`

```dart
Future<void> main() async
class CampusNotifyApp extends ConsumerStatefulWidget
  const CampusNotifyApp({super.key, required FirebaseBootstrap firebase})
```

| Aspek | Isi |
|---|---|
| Urutan bootstrap | `WidgetsFlutterBinding.ensureInitialized()` → `await bootstrapFirebase()` → `runApp(ProviderScope(overrides: [firebaseReadyProvider.overrideWithValue(...)]))` |
| Tema | `ColorScheme.fromSeed(seedColor: Color(0xFF0B6E4F))`, light + dark, `debugShowCheckedModeBanner: false` |
| Router | `ref.watch(appRouterProvider)` |
| FCM | `initState` → `addPostFrameCallback` → `_startPush()` → `pushProvider.notifier.start(firebaseReady:, firebaseNote:)`; `ref.listenManual(authControllerProvider)` memanggil `_startPush()` lagi pada login berikutnya |
| Siklus hidup | `AppLifecycleListener(onResume:)` → `notificationsProvider.notifier.reload()` |

**Invarian:** `start()` tidak boleh dipanggil sebelum frame pertama
(`getInitialMessage()` butuh router yang sudah terpasang); `routerConfig` tidak
boleh dibuat dengan `GoRouter(...)` baru di dalam `build`.

## 5. `test/`

| Berkas | Jumlah | Cakupan |
|---|---|---|
| `payload_test.dart` | 11 | `routeFromMessage` (4), `idFromMessage` (3), `Routes.sanitize` (2), `maskSecret` (2) |
| `api_client_test.dart` | 3 | 401 → refresh sekali → retry sukses (2 request); refresh mati → 1 request + sesi dibersihkan; tanpa refresh token → langsung bersihkan |
| `auth_test.dart` | 8 | Widget: guard route, sesi tersimpan, sesi setengah jadi, login valid, login invalid. Unit: refresh sukses, refresh ditolak, `maskedAccess` |
| `notification_test.dart` | 26 | `AppNotification` + mapper (5), `NotificationInbox` (4), `SharedPrefsInboxRepository` (4), `NotificationController` + badge (5), `relativeTime` (4), `authMessageFor` (3), widget "dibaca → hilang" (1) |
| `push_test.dart` | 14 | `PushState.copyWith` + `maskedToken` (5), `PushController` (9): start, token refresh, catatan `POST /devices`, izin ditolak, tanpa Firebase, pesan foreground, detach, tidak mencatat setelah detach, start ulang |

Total: **62 test**.

### 5.1 Fake yang tersedia

| Fake | Berkas | Isi |
|---|---|---|
| `FakeSessionRepository` | `auth_test.dart`, `api_client_test.dart`, `notification_test.dart` | `SessionRepository` berbasis memori + `clearCount` |
| `InMemoryKeyValueStore` | `notification_test.dart`, `push_test.dart` (dari `lib/data/datasources/`) | Penyimpanan kunci-nilai di memori |
| `RecordingBadge` | `notification_test.dart` | Merekam setiap angka badge tanpa platform channel |
| `FakePushMessaging` | `push_test.dart` | `PushMessaging` tanpa Firebase: stream yang dipicu manual, penghitung `prepare`/`subscribe`/`unsubscribe`, penampung banner |
| `FakeDeviceRepository` | `push_test.dart` | Merekam `register`/`unregister`; bisa menolak registrasi |
| `ScriptedAdapter` | `api_client_test.dart` | `HttpClientAdapter` yang mengembalikan 401 untuk token lama dan 200 untuk token baru |
| `DeadRefreshRepository` / `_RenewingRepository` | `api_client_test.dart` | `AuthRepository` yang selalu gagal / selalu berhasil refresh |

Pola umum: **override provider di `dependencies.dart`**, bukan me-*subclass*
kelas konkret. Contoh lengkap ada di
[`panduan-pengembangan.md`](panduan-pengembangan.md) bagian 8.1.

## 6. Invarian lintas berkas

| Invarian | Dikunci oleh |
|---|---|
| Token tidak pernah dirender utuh (`maskSecret` / `maskedToken`) | `test/payload_test.dart`, `test/push_test.dart`, `test/auth_test.dart` |
| `copyWith(note: null)` mengosongkan catatan | `test/push_test.dart` |
| Logout melepas listener FCM dan mengosongkan status | `test/push_test.dart` (`detach`) |
| `DELETE /devices` dijalankan sebelum sesi dihapus | `LogoutUseCase` + urutan di `home_page.dart` |
| Sesi setengah jadi dibersihkan, bukan dipakai | `test/auth_test.dart` |
| Satu request hanya diulang sekali setelah refresh | `test/api_client_test.dart` |
| Kotak masuk: dedupe, batas 50, data rusak tidak crash | `test/notification_test.dart` |
| Badge = jumlah notifikasi belum dibaca | `test/notification_test.dart`, `test/push_test.dart` |
| Tidak ada `presentation/` yang meng-import SDK | ditinjau manual + `flutter analyze` |
