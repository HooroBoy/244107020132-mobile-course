# Referensi kode

Kontrak setiap berkas di `lib/`, `test/`, dan `tools/`. Untuk gambaran alur dan
alasan desain, lihat [`arsitektur.md`](arsitektur.md).

## Cara membaca dokumen ini

- **Tanda tangan** ditulis seperti di kode, tanpa `import`.
- **Invarian** adalah aturan yang tidak boleh dilanggar saat mengubah berkas.
- **Dikunci oleh** menyebut test yang akan gagal bila perilaku berubah.
- "Deprecated" berarti sengaja dipakai dengan `// ignore:` beserta alasannya.

## Ringkasan berkas

| Berkas | Baris | Tanggung jawab |
|---|---|---|
| `lib/main.dart` | 89 | Bootstrap, `ProviderScope` (+ override `firebaseReadyProvider`), `MaterialApp.router`, memulai `PushController`, reload kotak masuk saat resume |
| `lib/routes.dart` | 21 | Konstanta path tunggal (termasuk `/notifikasi`) |
| `lib/data/token_store.dart` | 40 | Satu-satunya akses secure storage |
| `lib/data/masking.dart` | 8 | `maskSecret()` |
| `lib/data/auth_repository.dart` | 218 | Kontrak auth, `FirebaseAuthRepository`, `MockAuthRepository`, `authMessageFor()` |
| `lib/data/api_client.dart` | 85 | `buildApiClient()`: Dio + interceptor 401 |
| `lib/data/api_errors.dart` | 48 | `friendlyApiMessage()`, `AuthExpiredException` |
| `lib/data/device_repository.dart` | 48 | `POST` / `DELETE /devices` |
| `lib/data/notification_store.dart` | 191 | `AppNotification`, `KeyValueStore`, `NotificationStore` (kotak masuk) |
| `lib/data/badge_service.dart` | 28 | `BadgeService.setCount()` di atas `AppBadgePlus` |
| `lib/data/relative_time.dart` | 20 | `relativeTime()` — "5 mnt lalu" |
| `lib/messaging/firebase_bootstrap.dart` | 83 | Inisialisasi Firebase yang tidak fatal + handler background (mencatat ke kotak masuk) |
| `lib/messaging/payload.dart` | 32 | `routeFromMessage()`, `idFromMessage()` |
| `lib/messaging/push_service.dart` | 243 | Izin, token, topik, tiga handler, banner lokal, suara kustom |
| `lib/providers/auth_provider.dart` | 143 | `firebaseReadyProvider`, provider auth, `AuthNotifier` |
| `lib/providers/app_router.dart` | 70 | `GoRouter` + guard |
| `lib/providers/notification_providers.dart` | 108 | `NotificationCenter` + sinkron badge |
| `lib/providers/push_providers.dart` | 182 | `PushState`, `PushController` |
| `lib/pages/login_page.dart` | 214 | Form login |
| `lib/pages/home_page.dart` | 316 | Beranda: sesi, aksi, status notifikasi, lonceng badge |
| `lib/pages/notifications_page.dart` | 204 | Daftar notifikasi belum dibaca (reload saat dibuka) |
| `lib/pages/announcement_page.dart` | 80 | Target deep link `/pengumuman/:id` |

## `lib/main.dart`

```dart
Future<void> main() async
class CampusNotifyApp extends ConsumerStatefulWidget
  const CampusNotifyApp({super.key, required FirebaseBootstrap firebase})
```

| Aspek | Isi |
|---|---|
| Urutan bootstrap | `WidgetsFlutterBinding.ensureInitialized()` → `await bootstrapFirebase()` → `runApp(ProviderScope(...))` |
| Tema | `ColorScheme.fromSeed(seedColor: Color(0xFF0B6E4F))`, light + dark, `debugShowCheckedModeBanner: false` |
| Router | `ref.watch(appRouterProvider)` |
| FCM | `initState` → `addPostFrameCallback` → `pushProvider.notifier.start(firebaseReady:, firebaseNote:)` |
| Siklus hidup | `AppLifecycleListener(onResume:)` → `notificationsProvider.notifier.reload()` (menyusul entri yang ditulis handler background) |

**Invarian:** `start()` tidak boleh dipanggil sebelum frame pertama; `routerConfig`
tidak boleh dibuat dengan `GoRouter(...)` baru di dalam `build`.

## `lib/routes.dart`

```dart
abstract final class Routes {
  static const String login = '/login';
  static const String home = '/';
  static const String announcementPattern = '/pengumuman/:id';
  static const String announcementIdParam = 'id';
  static String announcement(String id) => '/pengumuman/$id';
}
```

**Invarian:** tidak ada string path literal di berkas lain. `Routes.home` dipakai
sebagai nilai aman untuk payload kosong.

## `lib/data/token_store.dart`

```dart
class TokenStore {
  TokenStore({FlutterSecureStorage? storage});
  Future<void> save({required String access, required String refresh, String? email});
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<String?> readEmail();
  Future<bool> hasSession();
  Future<void> clear();
}
```

| Kunci storage | Isi |
|---|---|
| `access_token` | Access token |
| `refresh_token` | Refresh token |
| `session_email` | Email pemilik sesi (opsional) |

**Invarian:** hanya berkas ini yang boleh meng-import
`flutter_secure_storage`. Konstruktor menerima `storage` agar test bisa
menyuntikkan implementasi lain (dipakai subclass fake di test).

**Catatan:** `clear()` memakai `deleteAll()`, jadi menghapus **semua** kunci milik
plugin pada aplikasi ini.

## `lib/data/masking.dart`

```dart
String maskSecret(String value)
```

| Panjang masukan | Keluaran |
|---|---|
| ≤ 12 | `••••••` |
| > 12 | 8 karakter awal + `••••` + 4 karakter akhir |

**Dikunci oleh:** `test/payload_test.dart` grup `maskSecret`.

## `lib/data/auth_repository.dart`

```dart
class AuthSession {
  const AuthSession({required String access, required String refresh, String? email});
  String get maskedAccess;
}

abstract class AuthRepository {
  Future<AuthSession> login({required String email, required String password});
  Future<String> refresh(String refreshToken);
}

abstract interface class SignOutCapable {
  Future<void> signOut();
}

const String kOpaqueRefreshToken = 'firebase:getIdToken';

class FirebaseAuthRepository implements AuthRepository, SignOutCapable {
  FirebaseAuthRepository({FirebaseAuth? auth});
}

class MockAuthRepository implements AuthRepository {
  const MockAuthRepository();
}

String authMessageFor(String code, String? fallback);

class AuthException implements Exception {
  const AuthException(String message);
  final String message;
}
```

### `FirebaseAuthRepository` (produksi)

| Perilaku | Detail |
|---|---|
| `login` | `signInWithEmailAndPassword` → `User.getIdToken()` (access) → `User.refreshToken` |
| Refresh tidak tersedia | Disimpan sebagai `kOpaqueRefreshToken`, bukan rahasia |
| `refresh` | `User.getIdToken(forceRefresh: true)`; argumen `refreshToken` sengaja diabaikan |
| `currentUser` null | `AuthException('Sesi Firebase tidak ditemukan. Silakan login ulang.')` |
| `FirebaseAuthException` | Diterjemahkan `authMessageFor()` → pesan Indonesia |
| `signOut()` | Menghapus sesi Firebase saat logout |

### `MockAuthRepository` (demo offline + test)

| Perilaku | Detail |
|---|---|
| `login` valid | Email mengandung `@` **dan** sandi ≥ 6 karakter |
| `login` tidak valid | `AuthException('Email atau kata sandi tidak valid')` |
| Token mock | `mock-access-for-<email>` / `mock-refresh-for-<email>` |
| Jeda buatan | 500 ms (login), 300 ms (refresh) — agar state loading terlihat |
| `refresh` kosong | `AuthException('Refresh token hilang atau kedaluwarsa')` |
| `refresh` = `mock-refresh-revoked` | `AuthException('Refresh token ditolak server')` |
| `refresh` berhasil | `mock-access-renewed-<epoch ms>` |

Pemilihan implementasi ada di `authRepositoryProvider` berdasarkan
`firebaseReadyProvider`. `authMessageFor()` memetakan kode Firebase
(`wrong-password`, `user-not-found`, `too-many-requests`, …) menjadi kalimat
yang aman ditampilkan; kode mentah tidak pernah sampai ke UI.

## `lib/data/api_client.dart`

```dart
const String kApiBaseUrl = 'https://example-campus-api.test';

Dio buildApiClient({
  required TokenStore store,
  required AuthRepository auth,
  required Future<void> Function() onSessionExpired,
  String baseUrl = kApiBaseUrl,
});
```

| Aspek | Nilai |
|---|---|
| `connectTimeout` | 10 detik |
| `receiveTimeout` | 10 detik |
| Penanda retry | `extra['auth_retried'] = true` (privat, `_retryFlag`) |
| Header otomatis | `Authorization: Bearer <access>` bila belum diset pemanggil |

Alur `onError`:

1. Bukan 401, atau sudah pernah diulang → teruskan error.
2. 401, refresh kosong → `store.clear()` + `onSessionExpired()` + teruskan error.
3. 401, refresh ada → `auth.refresh()` → `store.save(access: baru, refresh: lama)` →
   `dio.fetch(requestOptions)` dengan penanda retry → `handler.resolve(...)`.
4. Refresh melempar apa pun → `store.clear()` + `onSessionExpired()` + teruskan
   error **asli** (bukan error refresh).

**Invarian:** maksimal satu retry per request; refresh token lama tidak dihapus
kecuali sesi dibersihkan.

**Dikunci oleh:** `test/api_client_test.dart` (3 test: sukses retry, refresh
mati, refresh tidak tersimpan).

## `lib/data/api_errors.dart`

```dart
String friendlyApiMessage(Object error);
class AuthExpiredException implements Exception {
  const AuthExpiredException([this.message = 'Sesi berakhir. Silakan login ulang.']);
  final String message;
}
```

| Kondisi | Pesan |
|---|---|
| `AuthExpiredException` | `error.message` |
| Timeout (connect/send/receive/transform) | "Koneksi lambat. Coba lagi sebentar." |
| `connectionError` | "Tidak ada koneksi internet." |
| 401 | "Sesi berakhir. Silakan login ulang." |
| 403 | "Anda tidak punya akses ke data ini." |
| 404 | "Data tidak ditemukan." |
| ≥ 500 | "Server sedang bermasalah. Coba lagi nanti." |
| Status lain | "Permintaan ditolak server (<status>)." |
| `cancel` | "Permintaan dibatalkan." |
| `badCertificate` | "Sertifikat server tidak valid." |
| `unknown` / bukan `DioException` | "Terjadi kesalahan tak terduga." |

**Catatan:** `AuthExpiredException` saat ini tidak dilempar di mana pun; ia hanya
dikenali oleh `friendlyApiMessage`.

## `lib/data/device_repository.dart`

```dart
class DeviceRepository {
  const DeviceRepository(Dio dio);
  Future<bool> registerDevice({required String token, required String platform});
  Future<bool> unregisterDevice({required String token});
}
```

| Endpoint | Body | Sukses |
|---|---|---|
| `POST /devices` | `{"fcm_token": "<token>", "platform": "android"}` | status 2xx → `true` |
| `DELETE /devices` | `{"fcm_token": "<token>"}` | status 2xx → `true` |

**Invarian:** `DioException` ditangkap dan dikembalikan sebagai `false`; tidak ada
exception yang naik ke UI. Header `Authorization` disisipkan interceptor, bukan
oleh repository.

## `lib/data/notification_store.dart`

```dart
class AppNotification {
  const AppNotification({required this.id, required this.title, required this.body,
      required this.route, required this.receivedAt});
  factory AppNotification.fromMessage({String? messageId, required String title,
      required String body, required String route, DateTime? receivedAt});
  Map<String, dynamic> toJson();
  static AppNotification? fromJson(Map<String, dynamic> json);
}

abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PrefsKeyValueStore implements KeyValueStore { PrefsKeyValueStore({SharedPreferencesAsync? prefs}); }
class InMemoryKeyValueStore implements KeyValueStore { InMemoryKeyValueStore([Map<String, String>? initial]); }

class NotificationStore {
  NotificationStore(KeyValueStore store);
  static const String storageKey = 'campus_notif.inbox';
  static const int maxEntries = 50;
  Future<List<AppNotification>> load();
  Future<List<AppNotification>> append(AppNotification notification);
  Future<List<AppNotification>> remove(String id);
  Future<List<AppNotification>> clear();
}
```

| Perilaku | Detail |
|---|---|
| `id` | `messageId` FCM bila ada; jika tidak `<microsecondsSinceEpoch>-<route>` |
| Judul kosong | Diganti `Pengumuman` |
| `append` | Entri baru di depan; id sama diganti; dipotong pada `maxEntries` |
| `remove` | Menghapus satu entri (efek "dibaca") lalu menyimpan |
| `load` data rusak | Mengembalikan daftar kosong (tidak melempar) |
| `fromJson` tanpa id/route | `null` — entri dilewati |

**Dikunci oleh:** `test/notification_test.dart` grup `AppNotification` dan
`NotificationStore`.

## `lib/data/badge_service.dart`

```dart
class BadgeService {
  const BadgeService();
  Future<void> setCount(int count);
}
```

`isSupported()` lalu `updateBadge(n)`; nilai negatif dianggap 0; semua kegagalan
platform ditelan. **Dikunci oleh:** override `RecordingBadgeService` di
`test/notification_test.dart`.

## `lib/data/relative_time.dart`

```dart
String relativeTime(DateTime at, {DateTime? now});
```

`< 60 dtk` → `baru saja`; `< 60 mnt` → `N mnt lalu`; `< 24 jam` → `N jam lalu`;
`< 7 hari` → `N hr lalu`; selain itu `dd/MM/yyyy`. Waktu di masa depan →
`baru saja`. **Dikunci oleh:** grup `relativeTime` (4 test).

## `lib/messaging/firebase_bootstrap.dart`

```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message);

class FirebaseBootstrap {
  const FirebaseBootstrap({required bool ready, String? reason});
  const FirebaseBootstrap.notConfigured(String reason);
  final bool ready;
  final String? reason;
}

Future<FirebaseBootstrap> bootstrapFirebase();
```

| Perilaku | Detail |
|---|---|
| Sukses | `Firebase.initializeApp()` + daftarkan `onBackgroundMessage` → `ready: true` |
| Gagal, konfigurasi hilang | Pesan: "Firebase belum dikonfigurasi: letakkan google-services.json di android/app/ lalu build ulang." |
| Gagal, sebab lain | "Firebase gagal diinisialisasi: <error>" |
| Deteksi konfigurasi hilang | Pesan error mengandung `google-services`, `FirebaseOptions`, `not been correctly initialized`, atau `core/no-app` |
| Log di background | Hanya `messageId`; kegagalan pencatatan hanya mencetak `runtimeType` |
| Mencatat ke kotak masuk | `NotificationStore(PrefsKeyValueStore()).append(...)` dengan `DartPluginRegistrant.ensureInitialized()` lebih dulu |

**Invarian:** handler background wajib fungsi top-level, tidak boleh menyentuh
`BuildContext`, Riverpod, router, atau state UI; `bootstrapFirebase()` tidak
pernah melempar. Penulisan ke kotak masuk dibungkus `try/catch` agar kegagalan
penyimpanan tidak menggagalkan penayangan notifikasi oleh sistem.

## `lib/messaging/payload.dart`

```dart
String routeFromMessage(Map<String, dynamic> data);
String? idFromMessage(Map<String, dynamic> data);
```

Fungsi murni tanpa dependensi Firebase. Aturan lengkap ada di
[`arsitektur.md`](arsitektur.md) bagian 8.

**Dikunci oleh:** `test/payload_test.dart` grup `routeFromMessage` (4 test) dan
`idFromMessage` (3 test).

## `lib/messaging/push_service.dart`

```dart
const String kNotificationSoundResource = 'campus_notif';
const AndroidNotificationChannel kAnnouncementChannel;
const String kCampusTopic = 'pengumuman-kampus';

class PushService {
  PushService({FlutterLocalNotificationsPlugin? local, FirebaseMessaging? messaging});
  String? pendingDeepLink;
  Future<void> initLocalNotifications();
  Future<bool> requestPermission();
  Future<void> initFcmToken({required Future<void> Function(String token) onToken});
  Future<void> subscribeCampusTopic();
  Future<void> unsubscribeCampusTopic();
  Future<void> listenMessages({
    required void Function(String route) onRoute,
    required Future<void> Function(AppNotification notification) onNotification,
    required Future<void> Function(String? messageId, String route) onOpened,
  });
  Future<void> showLocalNotification({
    required String title, required String body, required String route,
  });
  String? consumePendingDeepLink();
  static String sanitizeRoute(String? route);
  static String get platformName;
}
```

| Anggota | Perilaku |
|---|---|
| `kNotificationSoundResource` | `campus_notif` → `android/app/src/main/res/raw/campus_notif.wav` |
| `kAnnouncementChannel` | id `pengumuman_v2`, nama `Pengumuman Kampus`, `Importance.high`, `playSound: true`, `sound: UriAndroidNotificationSound('campus_notif')`, `showBadge: true` |
| `initLocalNotifications()` | Idempoten (`_localReady`); ikon Android `@mipmap/ic_launcher`; iOS tidak meminta izin (dipusatkan di `requestPermission`); membuat channel eksplisit; ketukan → `sanitizeRoute(payload)` → `_onRoute` atau `pendingDeepLink` |
| `requestPermission()` | `alert`/`badge`/`sound` = `true`; `true` bila status `authorized` **atau** `provisional` |
| `initFcmToken()` | `getToken()` (deprecated, di-`ignore`) → `onToken`; lalu `onTokenRefresh.listen` → `onToken` |
| `subscribeCampusTopic()` | `subscribeToTopic('pengumuman-kampus')` |
| `listenMessages()` | Simpan `_onRoute`; `onMessage` → `onNotification` + banner; `onMessageOpenedApp` dan `getInitialMessage` → `onOpened(messageId, route)` |
| `showLocalNotification()` | Id = `epochMs % 100000`; `payload` = route; Android importance/priority high, suara kustom, getar, `channelShowBadge` |
| `sanitizeRoute()` | `null`/kosong → `/`; garis miring ditambahkan bila hilang |
| `platformName` | `web` bila `kIsWeb`, selain itu `defaultTargetPlatform.name` |

**Invarian:** kelas ini tidak meng-import Riverpod maupun `pages/`; navigasi
hanya lewat callback. `getToken`/`onTokenRefresh` deprecated tetapi
dipertahankan — alasannya di komentar `initFcmToken` dan
[`ai-challenge.md`](ai-challenge.md).

**Kenapa `pengumuman_v2`:** setelan channel Android bersifat *immutable*. Pada
perangkat yang sudah pernah membuat channel `pengumuman`, menambah suara kustom
tanpa mengganti id tidak berefek. Payload backend wajib ikut memakai
`channel_id: pengumuman_v2` (lihat `tools/send_fcm.py`).

## `lib/providers/auth_provider.dart`

```dart
final Provider<TokenStore> tokenStoreProvider;
final Provider<AuthRepository> authRepositoryProvider;
final Provider<Dio> apiClientProvider;
final AsyncNotifierProvider<AuthNotifier, AuthSession?> authStateProvider;

class AuthNotifier extends AsyncNotifier<AuthSession?> {
  Future<AuthSession?> build();
  Future<void> login(String email, String password);
  Future<bool> refreshSession();
  Future<void> logout();
  Future<void> forceLogout();
}
```

| Method | Perilaku | State akhir |
|---|---|---|
| `build()` | Baca access; kosong → `null`. Refresh kosong → `clear()` + `null` (sesi setengah jadi dibersihkan). Selain itu → `AuthSession` | `AsyncData` |
| `login()` | `AsyncLoading` → `AsyncValue.guard` (repository → `save`) | `AsyncData(session)` / `AsyncError` |
| `refreshSession()` | Tanpa refresh → `forceLogout`, `false`. Gagal → `forceLogout`, `false`. Sukses → simpan access baru, email dipertahankan, `true` | `AsyncData` |
| `logout()` | `_clearSession()` (token + `signOut()` Firebase bila didukung) | `AsyncData(null)` |
| `forceLogout()` | `_clearSession()` tanpa melempar | `AsyncData(null)` |

`firebaseReadyProvider` (default `false`) di-override di `main()` dengan hasil
`bootstrapFirebase()`; `authRepositoryProvider` memakainya untuk memilih
`FirebaseAuthRepository` atau `MockAuthRepository`.

**Dikunci oleh:** `test/auth_test.dart` (8 test).

## `lib/providers/app_router.dart`

```dart
final Provider<GoRouter> appRouterProvider;
class _AuthRefresh extends ChangeNotifier; // privat
```

| Rute | Widget |
|---|---|
| `/login` | `LoginPage` |
| `/` | `HomePage` |
| `/notifikasi` | `NotificationsPage` |
| `/pengumuman/:id` | `AnnouncementPage(id: state.pathParameters['id'] ?? '')` |

`initialLocation: Routes.home`, `refreshListenable: _AuthRefresh`. Guard
mengembalikan `null` selama `auth.isLoading && !auth.hasValue`.

## `lib/providers/push_providers.dart`

```dart
final Provider<PushService> pushServiceProvider;
final Provider<DeviceRepository> deviceRepositoryProvider;
final NotifierProvider<PushController, PushState> pushProvider;

class PushState {
  const PushState({
    this.started = false, this.permissionGranted = false, this.token,
    this.registeredOnBackend = false, this.subscribedTopic = false,
    this.lastRoute, this.note,
  });
  String get maskedToken;
  PushState copyWith({...});
}

class PushController extends Notifier<PushState> {
  PushState build();
  Future<void> start({required bool firebaseReady, String? firebaseNote});
  Future<void> sendTestNotification();
  Future<void> toggleTopic(bool subscribe);
}
```

| Method | Urutan kerja |
|---|---|
| `start()` | Kembali bila `state.started`; bila `!firebaseReady` → `note` saja dan berhenti; `initLocalNotifications` → `requestPermission` → `initFcmToken(_registerToken)` → `subscribeCampusTopic` → `listenMessages(onRoute: _go, onNotification: _record, onOpened: _openFromNotification)` → `consumePendingDeepLink` |
| `sendTestNotification()` | Catat ke kotak masuk **dan** tampilkan banner lokal "Jadwal kuliah berubah" → `/pengumuman/3` |
| `toggleTopic(bool)` | `subscribe` / `unsubscribe` lalu perbarui `subscribedTopic` |
| `_record()` | `notificationsProvider.add(...)` — menandai notifikasi belum dibaca |
| `_openFromNotification()` | `markRead(messageId)` lalu `_go(route)`; diketuk berarti sudah dibaca |

**Catatan `copyWith`:** parameter `null` berarti "pertahankan nilai lama", jadi
`note` tidak bisa dikosongkan lewat `copyWith(note: null)`.

**Dikunci oleh:** tidak ada test khusus untuk `PushController`; logika kotak
masuk yang dipanggilnya dikunci di `test/notification_test.dart`, sedangkan
perilaku runtime terlihat di `screenshots/01-home-status-fcm.png`.

## `lib/providers/notification_providers.dart`

```dart
final Provider<KeyValueStore> keyValueStoreProvider;
final Provider<NotificationStore> notificationStoreProvider;
final Provider<BadgeService> badgeServiceProvider;
final NotifierProvider<NotificationCenter, List<AppNotification>> notificationsProvider;

class NotificationCenter extends Notifier<List<AppNotification>> {
  int get unreadCount;
  Future<void> reload();
  Future<void> add(AppNotification notification);
  Future<void> markRead(String id);
  Future<void> markAllRead();
}
```

| Anggota | Perilaku |
|---|---|
| `build()` | `[]` lalu `reload()` dijadwalkan lewat microtask |
| `reload()` | Baca ulang penyimpanan (entri dari handler background) |
| `add()` | Catat sebagai belum dibaca + sinkron badge |
| `markRead()` | Hapus entri + sinkron badge |
| `markAllRead()` | Kosongkan daftar + badge 0 |
| `unreadCount` | `state.length` |

Semua operasi menelan kegagalan penyimpanan agar UI tidak crash, dan penanda
`_disposed` mencegah penulisan state setelah provider dibuang.
**Dikunci oleh:** grup `NotificationCenter` (4 test) + widget test "dibaca →
hilang".

## `lib/pages/login_page.dart`

```dart
class LoginPage extends ConsumerStatefulWidget
```

| Elemen | Detail |
|---|---|
| Field | Email (`Icons.alternate_email`), kata sandi (`Icons.lock_outline`) dengan tombol tampil/sembunyi |
| Validasi email | Kosong → "Email wajib diisi"; tanpa `@` → "Format email tidak valid" |
| Validasi sandi | Kosong → "Kata sandi wajib diisi"; < 6 → "Minimal 6 karakter" |
| Aksi | `FilledButton` "Masuk"; spinner saat `_busy`; `onFieldSubmitted` juga mengirim |
| Error | Kotak `errorContainer` dari `AuthException.message` atau `friendlyApiMessage()` |
| Navigasi | **Tidak ada** — guard `GoRouter` yang memindahkan |
| Catatan UI | Saat Firebase siap: "Masuk memakai akun Firebase Authentication…"; saat belum: "Mode praktikum: Firebase belum dikonfigurasi, autentikasi memakai mock…" (membaca `firebaseReadyProvider`) |

**Invarian:** `_busy` mencegah submit ganda; `if (!mounted) return;` sebelum
`setState` setelah `await`.

## `lib/pages/home_page.dart`

```dart
class HomePage extends ConsumerWidget
class _SessionView extends ConsumerWidget   // privat
class _PushCard extends ConsumerWidget     // privat
class _NotificationBell extends ConsumerWidget // privat
class _Row extends StatelessWidget         // privat
class _ErrorView extends StatelessWidget   // privat
```

| Bagian | Isi |
|---|---|
| `AppBar` | Judul "Campus Notify", lonceng (`_NotificationBell`) → `/notifikasi`, tombol `Icons.logout` → `logout()` |
| `_NotificationBell` | `Badge` Material 3 dengan angka `notificationsProvider.length`; label tersembunyi saat 0 |
| Loading | `CircularProgressIndicator` saat `isLoading && !hasValue` |
| Error | `_ErrorView` + tombol "Coba lagi" → `ref.invalidate(authStateProvider)` |
| Kartu "Sesi aktif" | Email, access token **terpotong**, catatan "disimpan di flutter_secure_storage" |
| Aksi 1 | "Jadwal kuliah berubah" → `context.go(Routes.announcement('3'))` |
| Aksi 2 | "Uji refresh token" → `refreshSession()`; SnackBar sukses (token terpotong) atau gagal |
| Kartu "Status notifikasi" | Token terpotong, izin, topik, laporan backend, deep link terakhir, `note` (merah), tombol "Tampilkan notifikasi uji" |
| Jaring pengaman | Bila `session == null` → teks "Belum ada sesi." |

**Invarian:** token utuh tidak pernah dirender; gunakan `session.maskedAccess`
dan `push.maskedToken`. Cek `context.mounted` setelah `await` sebelum memakai
`ScaffoldMessenger`/`context`.

## `lib/pages/notifications_page.dart`

`ConsumerStatefulWidget`. AppBar menampilkan `Notifikasi (n)`, aksi `done_all`
(tandai semua dibaca), dan tombol kembali (`pop` bila memungkinkan, jika tidak ke
`/`). Isi: `_EmptyState` atau `ListView.separated` berisi `_NotificationTile`.

| Aksi | Efek |
|---|---|
| Halaman dibuka | `initState` → `reload()` (menyusul entri dari handler background) |
| Mengetuk tile | `markRead(id)` → entri hilang → `context.push(item.route)` |
| Tarik ke bawah | `reload()` dari penyimpanan |
| `done_all` | `markAllRead()` → daftar & badge jadi 0 |

## `lib/pages/announcement_page.dart`

```dart
class AnnouncementPage extends StatelessWidget
  const AnnouncementPage({super.key, required String id})
```

| Aspek | Detail |
|---|---|
| Sumber `id` | `state.pathParameters['id']` dari router, bukan state halaman lain |
| Isi | `Chip` "id: <id>", judul, isi pengumuman contoh, kartu penjelasan deep link |
| Tombol kembali | `context.canPop()` → `pop()`, selain itu `go('/')` (penting untuk kasus terminated, saat tidak ada riwayat) |

## `test/`

| Berkas | Jumlah test | Cakupan |
|---|---|---|
| `test/payload_test.dart` | 11 | `routeFromMessage` (4), `idFromMessage` (3), `sanitizeRoute` (2), `maskSecret` (2) |
| `test/api_client_test.dart` | 3 | 401 → refresh → retry sukses; refresh mati → sesi dibersihkan tanpa retry; refresh tidak tersimpan → langsung bersihkan |
| `test/auth_test.dart` | 8 | Guard route, sesi tersimpan, sesi setengah jadi, login valid/tidak valid, refresh sukses/ditolak, `maskedAccess` |
| `test/notification_test.dart` | 23 | `AppNotification` (5), `NotificationStore` (6), `NotificationCenter` + badge (4), `relativeTime` (4), `authMessageFor` (3), widget test "dibaca → hilang" (1) |
| **Total** | **45** | `flutter test` → `All tests passed!` |

### Alat bantu test yang bisa dipakai ulang

| Alat | Berkas | Fungsi |
|---|---|---|
| `FakeTokenStore` | `test/auth_test.dart`, `test/notification_test.dart` | `TokenStore` berbasis memori + `clearCount` |
| `MemoryTokenStore` | `test/api_client_test.dart` | Sama, tanpa email |
| `ScriptedAdapter` | `test/api_client_test.dart` | `HttpClientAdapter` palsu: 401 untuk token lama, 200 untuk token baru; merekam header |
| `DeadRefreshRepository` / `_RenewingRepository` | `test/api_client_test.dart` | `AuthRepository` yang selalu gagal / selalu memberi access baru |
| `RecordingBadgeService` | `test/notification_test.dart` | Merekam angka badge tanpa platform channel |
| `InMemoryKeyValueStore` | `lib/data/notification_store.dart` | Penyimpanan kotak masuk di memori |

Pola penting: test widget memakai
`CampusNotifyApp(firebase: FirebaseBootstrap.notConfigured('test'))` sehingga
`PushController` berhenti sebelum menyentuh platform channel Firebase, dan
meng-override `keyValueStoreProvider` + `badgeServiceProvider` agar tidak ada
plugin yang dipanggil.

## `tools/send_fcm.py`

```text
python tools/send_fcm.py [--id N] [--token FCM] [--data-only]
```

| Argumen | Default | Fungsi |
|---|---|---|
| `--id` | `3` | Mengisi `data.route = /pengumuman/<id>` dan `data.id` |
| `--token` | – | Kirim ke satu perangkat; tanpa ini dikirim ke topik `pengumuman-kampus` |
| `--data-only` | mati | Menghilangkan blok `notification` (menguji jalur `data`) |

Padanan PowerShell `tools/send_fcm.ps1` memakai parameter `-Id`, `-Token`,
`-DataOnly` dan mengirim payload yang sama. Skrip ini menandatangani JWT RS256
lewat `openssl` lalu memanggil FCM dengan `curl`, sehingga tidak butuh paket
Python. Berguna di Windows yang belum memasang `requests`/`google-auth`.

Prasyarat: `.secrets/service-account.json` (tidak masuk version control),
paket Python `requests` dan `google-auth`. Skrip mencetak project, target, data,
channel, status HTTP, lalu keluar dengan kode 1 bila status ≠ 200.
`CHANNEL_ID` di skrip ini **wajib** sama dengan `kAnnouncementChannel.id`
(`pengumuman_v2`), kalau tidak Android memakai channel default tanpa suara
kustom.

## `tools/make_app_icon.ps1`

```text
powershell -ExecutionPolicy Bypass -File tools/make_app_icon.ps1
dart run flutter_launcher_icons
```

Menghasilkan `assets/icon/app_icon.png` (ikon penuh, latar gradasi hijau) dan
`assets/icon/app_icon_foreground.png` (lapisan depan adaptive icon, transparan).
Keduanya dirujuk blok `flutter_launcher_icons` di `pubspec.yaml`.

## Konstanta dan nilai tetap

| Nama | Nilai | Berkas |
|---|---|---|
| `kApiBaseUrl` | `https://example-campus-api.test` | `data/api_client.dart` |
| `kCampusTopic` | `pengumuman-kampus` | `messaging/push_service.dart` |
| `kAnnouncementChannel.id` | `pengumuman_v2` | `messaging/push_service.dart` |
| `kAnnouncementChannel.name` | `Pengumuman Kampus` | `messaging/push_service.dart` |
| `kNotificationSoundResource` | `campus_notif` | `messaging/push_service.dart` |
| `NotificationStore.storageKey` | `campus_notif.inbox` | `data/notification_store.dart` |
| `NotificationStore.maxEntries` | `50` | `data/notification_store.dart` |
| `kOpaqueRefreshToken` | `firebase:getIdToken` | `data/auth_repository.dart` |
| `Routes.login` | `/login` | `routes.dart` |
| `Routes.home` | `/` | `routes.dart` |
| `Routes.notifications` | `/notifikasi` | `routes.dart` |
| `Routes.announcementPattern` | `/pengumuman/:id` | `routes.dart` |
| Warna seed tema | `0xFF0B6E4F` | `main.dart` |
| Application ID | `com.horoboy.campusnotif` | `android/app/build.gradle.kts` |
| Timeout Dio | 10 s (connect, receive) | `data/api_client.dart` |

## Invarian proyek (checklist review)

1. Token hanya di `flutter_secure_storage`; `shared_preferences` khusus kotak
   masuk notifikasi (bukan rahasia).
2. Tidak ada `print`/`debugPrint` yang memuat token atau payload penuh.
3. Tidak ada string path literal; selalu lewat `Routes`.
4. Semua token yang tampil melewati `maskSecret()`.
5. Handler background tetap fungsi top-level `@pragma('vm:entry-point')` tanpa
   `BuildContext`/Riverpod.
6. Navigasi dari notifikasi lewat `router.go()` pada router yang sudah ada,
   bukan `Navigator.push` atau router baru.
7. `bootstrapFirebase()` tetap tidak melempar.
8. Angka badge selalu berasal dari `notificationsProvider.length` — tidak ada
   penghitung terpisah yang bisa menyimpang.
9. Kegagalan platform (badge, penyimpanan, `signOut`) tidak boleh membuat
   aplikasi crash; semuanya dibungkus `try/catch` bertipe `on Object`.
10. `flutter analyze` bersih dan `flutter test` hijau sebelum commit.

