# Arsitektur Campus Notify

Dokumen ini menjelaskan bagaimana bagian-bagian aplikasi tersusun dan bagaimana
data bergerak di antaranya. Untuk kontrak fungsi per berkas, lihat
[`referensi-kode.md`](referensi-kode.md); untuk cara mengubah kode, lihat
[`panduan-pengembangan.md`](panduan-pengembangan.md).

## 1. Tujuan arsitektur

Aplikasi ini kecil, tetapi menggabungkan empat hal yang mudah saling
mengganggu: penyimpanan rahasia, klien HTTP dengan retry, navigasi berbasis
rute, dan pesan yang datang dari luar proses aplikasi. Karena itu batasannya
dibuat tegas:

| Batasan | Konsekuensi desain |
|---|---|
| Token tidak boleh bocor ke log, UI, atau `SharedPreferences` | Hanya `TokenStore` yang menyentuh `flutter_secure_storage`; semua tampilan token lewat `maskSecret()` |
| Navigasi tidak boleh bergantung pada `BuildContext` dari lapisan non-UI | `PushService` menerima callback `onRoute`; navigasi dijalankan `PushController` lewat `GoRouter` global |
| Kode yang bergantung platform harus bisa diuji | Parsing payload dipisah ke fungsi murni `messaging/payload.dart`; store dan repository bisa di-*override* di test |
| Aplikasi harus tetap hidup tanpa Firebase | `bootstrapFirebase()` menangkap kegagalan dan melaporkannya sebagai status, bukan crash |
| Satu sumber kebenaran untuk path | Semua path berasal dari `Routes` di `lib/routes.dart` |

## 2. Peta lapisan

```mermaid
flowchart TB
  subgraph UI["lib/pages — UI"]
    LP["LoginPage"]
    HP["HomePage<br/>(lonceng + badge)"]
    NP["NotificationsPage"]
    AP["AnnouncementPage"]
  end

  subgraph STATE["lib/providers — state & DI"]
    RTR["appRouterProvider<br/>GoRouter + guard"]
    AUTH["authStateProvider<br/>AuthNotifier"]
    PUSH["pushProvider<br/>PushController"]
    INBOX["notificationsProvider<br/>NotificationCenter"]
    APIC["apiClientProvider<br/>Dio"]
  end

  subgraph DATA["lib/data — sumber data"]
    TS["TokenStore"]
    AUR["AuthRepository<br/>(Firebase / mock)"]
    DVR["DeviceRepository"]
    NS["NotificationStore"]
    BS["BadgeService"]
    RT["relative_time"]
    ERR["api_errors"]
    MSK["masking"]
  end

  subgraph MSG["lib/messaging — FCM"]
    PS["PushService"]
    FB["firebase_bootstrap"]
    PL["payload.dart<br/>(fungsi murni)"]
  end

  LP --> AUTH
  HP --> AUTH
  HP --> PUSH
  HP --> INBOX
  NP --> INBOX
  AP --> RTR
  RTR --> AUTH
  PUSH --> RTR
  PUSH --> DVR
  PUSH --> PS
  PUSH --> INBOX
  INBOX --> NS
  INBOX --> BS
  APIC --> TS
  APIC --> AUR
  DVR --> APIC
  AUTH --> TS
  AUTH --> AUR
  PS --> PL
  FB --> NS
  NP --> RT
  AUR --> MSK
  PUSH --> MSK
  LP --> ERR
  FB -.-> PS
```

Aturan arah dependency: **UI → state → data/messaging**. Tidak ada berkas di
`data/` atau `messaging/` yang meng-import `pages/`, dan `messaging/` tidak
meng-import Riverpod sama sekali.

## 3. Bootstrap dan siklus hidup

```mermaid
sequenceDiagram
  participant M as main()
  participant FB as bootstrapFirebase()
  participant PS as ProviderScope
  participant APP as CampusNotifyApp
  participant PC as PushController
  M->>M: WidgetsFlutterBinding.ensureInitialized()
  M->>FB: bootstrapFirebase()
  alt google-services.json ada
    FB-->>M: FirebaseBootstrap(ready: true)
  else konfigurasi hilang / platform tak didukung
    FB-->>M: FirebaseBootstrap.notConfigured(reason)
  end
  M->>PS: runApp(ProviderScope(child: CampusNotifyApp))
  PS->>APP: build
  APP->>APP: MaterialApp.router(routerConfig: appRouterProvider)
  Note over APP: initState mendaftarkan addPostFrameCallback
  APP->>PC: start(firebaseReady, firebaseNote)
  PC->>PC: izin → token → topik → handler → pending deep link
```

Dua detail yang mudah salah dan sengaja ditangani:

1. **`bootstrapFirebase()` di-`await` sebelum `runApp`.** FCM memerlukan
   instance Firebase yang sudah siap; tanpa itu `getToken()` gagal.
2. **`PushController.start()` ditunda satu frame.** `getInitialMessage()`
   (notifikasi yang membuka aplikasi dari terminated) bisa selesai lebih cepat
   daripada `GoRouter` terpasang. `addPostFrameCallback` memastikan router sudah
   ada sebelum navigasi pertama dijalankan.

## 4. Graf dependency provider

```mermaid
flowchart LR
  FB["firebaseReadyProvider"] --> AUR["authRepositoryProvider"]
  TS["tokenStoreProvider"] --> APIC["apiClientProvider"]
  AUR --> APIC
  TS --> AUTH["authStateProvider"]
  AUR --> AUTH
  APIC --> DVR["deviceRepositoryProvider"]
  PS["pushServiceProvider"] --> PUSH["pushProvider"]
  DVR --> PUSH
  AUTH --> RTR["appRouterProvider"]
  RTR --> PUSH
  KV["keyValueStoreProvider"] --> NSTORE["notificationStoreProvider"]
  NSTORE --> NC["notificationsProvider"]
  BADGE["badgeServiceProvider"] --> NC
  NC --> PUSH
```

| Provider | Tipe | Isi | Bisa di-*override* saat test |
|---|---|---|---|
| `firebaseReadyProvider` | `Provider<bool>` | Hasil `bootstrapFirebase()`; default `false` | Ya — di-`main()` dan di test |
| `tokenStoreProvider` | `Provider<TokenStore>` | Satu-satunya akses ke secure storage | Ya — dipakai `test/auth_test.dart` dan `test/api_client_test.dart` |
| `authRepositoryProvider` | `Provider<AuthRepository>` | `FirebaseAuthRepository` bila Firebase siap, `MockAuthRepository` bila tidak | Ya |
| `apiClientProvider` | `Provider<Dio>` | Dio + interceptor refresh, `onSessionExpired` → `forceLogout()` | Tidak (dibangun ulang bila dependency berubah) |
| `authStateProvider` | `AsyncNotifierProvider<AuthNotifier, AuthSession?>` | Status sesi; `null` = belum login | Ya, lewat override store |
| `pushServiceProvider` | `Provider<PushService>` | Pembungkus FCM + local notification | Ya (bisa diisi fake `FirebaseMessaging`) |
| `deviceRepositoryProvider` | `Provider<DeviceRepository>` | `POST` / `DELETE /devices` | Ya |
| `pushProvider` | `NotifierProvider<PushController, PushState>` | Orkestrasi izin, token, topik, handler, navigasi, pencatatan notifikasi | Ya |
| `keyValueStoreProvider` | `Provider<KeyValueStore>` | `shared_preferences` untuk kotak masuk | Ya — `InMemoryKeyValueStore` |
| `notificationStoreProvider` | `Provider<NotificationStore>` | Baca/tulis daftar notifikasi belum dibaca | Ya |
| `badgeServiceProvider` | `Provider<BadgeService>` | Angka badge pada ikon aplikasi | Ya |
| `notificationsProvider` | `NotifierProvider<NotificationCenter, List<AppNotification>>` | Daftar notifikasi belum dibaca + sinkron badge | Ya (lewat store & badge) |
| `appRouterProvider` | `Provider<GoRouter>` | Router + guard route | Ya |

Satu-satunya ketergantungan yang berpotensi melingkar adalah
`apiClientProvider` → `authStateProvider` (lewat `onSessionExpired`). Itu
diselesaikan dengan `ref.read(authStateProvider.notifier)` **di dalam callback**,
bukan saat provider dibangun, sehingga tidak ada siklus inisialisasi.

## 5. Alur login (Firebase Authentication)

```mermaid
sequenceDiagram
  participant U as Pengguna
  participant LP as LoginPage
  participant AN as AuthNotifier
  participant AR as FirebaseAuthRepository
  participant FA as FirebaseAuth SDK
  participant TS as TokenStore
  participant GR as GoRouter

  U->>LP: isi email + kata sandi, tekan Masuk
  LP->>LP: validasi form (email mengandung "@", sandi ≥ 6)
  LP->>AN: login(email, password)
  AN->>AN: state = AsyncLoading
  AN->>AR: login(email, password)
  AR->>FA: signInWithEmailAndPassword(email, password)
  alt ditolak Firebase
    FA-->>AR: FirebaseAuthException(code)
    AR-->>AN: AuthException(pesan Indonesia)
    AN-->>LP: state = AsyncError (pesan tampil di form)
  else diterima
    FA-->>AR: UserCredential(user)
    AR->>FA: user.getIdToken()
    FA-->>AR: ID token (access)
    AR-->>AN: AuthSession(access, refresh, email)
    AN->>TS: save(access, refresh, email)
    AN-->>LP: state = AsyncData(session)
  end
  TS-->>GR: state berubah → refreshListenable.notifyListeners()
  GR->>GR: redirect: loggedIn && atLogin → '/'
  GR-->>U: HomePage tampil
```

Pemilihan implementasi dilakukan `authRepositoryProvider`:

| `firebaseReadyProvider` | Implementasi | Perilaku |
|---|---|---|
| `true` | `FirebaseAuthRepository` | Login sungguhan; access = ID token, refresh = `User.refreshToken` (atau penanda `firebase:getIdToken` bila platform tidak mengeksposnya) |
| `false` | `MockAuthRepository` | Demo offline + test: email mengandung `@`, sandi ≥ 6 karakter |

Poin penting: **`LoginPage` tidak pernah memanggil `context.go()`.** Perpindahan
layar sepenuhnya hasil keputusan guard di `appRouterProvider`, sehingga satu
sumber kebenaran berlaku untuk login, logout, dan sesi yang kedaluwarsa.

`AuthNotifier.build()` saat aplikasi dibuka hanya membaca secure storage — ia
**tidak** memanggil jaringan untuk memvalidasi token. Konsekuensi yang perlu
diketahui: token yang sudah mati di server tetap dianggap sesi aktif sampai ada
request yang menerima 401 (lihat bagian 6).

Logout menghapus dua hal: token di secure storage **dan** sesi Firebase
(`SignOutCapable.signOut()`). Tanpa yang kedua, SDK Firebase akan memulihkan
sesinya sendiri saat aplikasi dibuka sehingga pengguna tampak "tidak pernah
logout".

## 6. Alur 401 → refresh → retry

```mermaid
sequenceDiagram
  participant C as Pemanggil
  participant D as Dio + interceptor
  participant S as TokenStore
  participant R as AuthRepository
  participant F as onSessionExpired

  C->>D: GET /resource
  D->>S: readAccess()
  D->>D: kirim dengan Authorization: Bearer <access>
  D-->>D: respons 401
  alt extra['auth_retried'] == true
    D-->>C: error diteruskan (tidak ada retry kedua)
  else refresh token tidak ada / kosong
    D->>S: clear()
    D->>F: forceLogout()
    D-->>C: error 401 asli
  else refresh tersedia
    D->>R: refresh(refreshToken)
    alt refresh berhasil
      R-->>D: access baru
      D->>S: save(access baru, refresh lama)
      D->>D: fetch ulang dengan auth_retried = true
      D-->>C: respons sukses
    else refresh ditolak / error
      D->>S: clear()
      D->>F: forceLogout()
      D-->>C: error 401 asli
    end
  end
```

Jaminan yang diberikan interceptor:

| Jaminan | Cara dipenuhi |
|---|---|
| Satu request hanya diulang **sekali** | Penanda `extra['auth_retried']` di `RequestOptions` |
| Refresh token tidak ikut berputar | `save(access: renewed, refresh: refreshToken)` — refresh lama dipertahankan |
| Header pemanggil tidak ditimpa | `Authorization` hanya diisi bila belum ada |
| Kegagalan tidak membuat pengguna terjebak | `onSessionExpired` → `forceLogout()` → guard route memindahkan ke `/login` |

Catatan untuk backend nyata: beberapa server menerapkan **rotasi refresh
token** (refresh lama langsung mati setelah dipakai). Bila server Anda begitu,
`auth.refresh()` harus mengembalikan pasangan token baru dan baris `save(...)`
di `api_client.dart` perlu memakai refresh yang baru juga.

## 7. Alur notifikasi FCM

```mermaid
sequenceDiagram
  participant APP as PushController.start()
  participant PS as PushService
  participant FCM as FirebaseMessaging
  participant DR as DeviceRepository
  participant R as GoRouter

  APP->>PS: initLocalNotifications()
  PS->>PS: buat channel "pengumuman_v2" (importance HIGH, suara campus_notif)
  APP->>PS: requestPermission()
  PS->>FCM: requestPermission(alert, badge, sound)
  FCM-->>PS: AuthorizationStatus
  APP->>PS: initFcmToken(onToken: _registerToken)
  PS->>FCM: getToken()
  FCM-->>PS: token
  PS->>DR: registerDevice(token, platform)
  DR-->>PS: bool (gagal jaringan → false, tidak crash)
  PS->>FCM: onTokenRefresh.listen(...)
  APP->>PS: subscribeCampusTopic()
  PS->>FCM: subscribeToTopic("pengumuman-kampus")
  APP->>PS: listenMessages(onRoute, onNotification, onOpened)
  PS->>FCM: onMessage / onMessageOpenedApp / getInitialMessage
  FCM-->>PS: pesan
  PS->>PS: onNotification → NotificationCenter.add (belum dibaca + badge)
  PS->>PS: showLocalNotification (banner + suara kustom)
  PS->>R: onOpened → markRead(id) → router.go(route)
```

Tiga app state ditangani oleh tiga jalur berbeda. Ini bukan pilihan gaya, tapi
konsekuensi dari cara Android dan FCM bekerja:

| State | Kondisi aplikasi | Handler | Siapa yang menampilkan banner |
|---|---|---|---|
| Foreground | Aplikasi terbuka di layar | `FirebaseMessaging.onMessage` | Aplikasi sendiri lewat `flutter_local_notifications` (sistem tidak menampilkannya) |
| Background | Proses hidup, aplikasi tidak di layar | `onMessageOpenedApp` (saat diketuk) | Sistem (shade notifikasi) |
| Terminated | Proses sudah mati | `getInitialMessage` saat aplikasi dibuka | `FlutterFirebaseMessagingBackgroundService` |

Handler background **tidak** menampilkan notifikasi sendiri. Bila itu
dilakukan, pengguna di background akan melihat dua banner untuk satu pesan —
alasannya dibahas di [`ai-challenge.md`](ai-challenge.md) bagian 4.1.

## 8. Resolusi deep link

Tujuan navigasi selalu berasal dari `data` payload, tidak pernah dari
`notification` (judul/isi hanya untuk tampilan). Tiga fungsi menanganinya:

```mermaid
flowchart LR
  P["data payload FCM"] --> RF["routeFromMessage()"]
  RF --> SR["sanitizeRoute()"]
  SR --> GO["router.go(route)"]
  P --> ID["idFromMessage()"]
  ID --> PAGE["AnnouncementPage(id)"]
```

| Masukan | `routeFromMessage` | Alasan |
|---|---|---|
| `{}` atau tanpa `route` | `/` (beranda) | Jaring pengaman: payload rusak tidak boleh membuat aplikasi tanpa tujuan |
| `{'route': ''}` / spasi saja | `/` | String kosong bukan rute |
| `{'route': 123}` (bukan string) | `/` | `data` FCM seharusnya string; tipe lain diabaikan |
| `{'route': 'pengumuman/3'}` | `/pengumuman/3` | Backend sering lupa garis miring di depan |
| `{'route': '  /pengumuman/9  '}` | `/pengumuman/9` | Spasi tepi dibuang |

| Masukan | `idFromMessage` | Alasan |
|---|---|---|
| `{'id': '7', 'route': '/pengumuman/3'}` | `'7'` | `data.id` diutamakan |
| `{'route': '/pengumuman/3'}` | `'3'` | Fallback ke segmen terakhir `route` |
| `{}` atau `{'route': '/'}` | `null` | Tidak ada pengumuman yang dituju |

`sanitizeRoute` adalah versi aman untuk nilai dari luar (mis. `payload` banner
lokal yang bisa `null`): nilai kosong menjadi `/`, dan garis miring ditambahkan
bila hilang.

## 9. Kotak masuk notifikasi, badge, dan suara

### 9.1 Dari notifikasi ke daftar

```mermaid
flowchart TB
  A["Pesan FCM masuk"] --> B{"Aplikasi di foreground?"}
  B -- ya --> C["onMessage<br/>catat + banner lokal"]
  B -- tidak --> D["firebaseMessagingBackgroundHandler<br/>(isolate terpisah)"]
  D --> E["NotificationStore.append()<br/>tulis ke shared_preferences"]
  C --> F["NotificationCenter.state"]
  E -.->|"reload() saat app kembali aktif<br/>dan saat /notifikasi dibuka"| F
  F --> G["Badge: AppBadgePlus.updateBadge(n)"]
  F --> H["Halaman /notifikasi"]
  H -->|"entri diketuk"| I["markRead(id) - entri dihapus"]
  I --> G
```

Handler background berjalan di isolate lain, jadi `NotificationCenter` di isolate UI
tidak tahu ada entri baru. Karena itu `reload()` dipanggil di dua titik:
`AppLifecycleListener(onResume:)` di `main.dart` (aplikasi kembali aktif) dan
`initState` halaman `/notifikasi` (halaman dibuka). Tanpa keduanya, notifikasi
yang masuk saat aplikasi di background hanya terlihat setelah aplikasi dibuka ulang.

| Kejadian | Yang dicatat | Status |
|---|---|---|
| FCM masuk saat aplikasi terbuka | `onMessage` → `PushController._record` | Belum dibaca |
| FCM masuk saat aplikasi di background/terminated | handler background menulis ke penyimpanan | Belum dibaca |
| Notifikasi sistem diketuk | `_openFromNotification` menghapus entri ber-id sama | Sudah dibaca |
| Entri di `/notifikasi` diketuk | `markRead(id)` | Sudah dibaca (hilang) |
| "Tandai semua dibaca" | `markAllRead()` | Semua hilang |

Definisi "dibaca" di aplikasi ini: **entri tidak lagi ada di daftar**. Karena itu
`NotificationCenter.state.length` selalu sama dengan angka badge, dan tidak ada
field `read` yang bisa menjadi tidak konsisten.

### 9.2 Penyimpanan

- `NotificationStore` menyimpan JSON pada satu kunci `campus_notif.inbox` lewat
  `KeyValueStore`.
- Implementasi nyata: `PrefsKeyValueStore` (`shared_preferences`).
- Implementasi test: `InMemoryKeyValueStore`.
- Batas `maxEntries = 50`; entri dengan `id` sama diganti, bukan diduplikasi.
- Data rusak (bukan JSON) menghasilkan daftar kosong, bukan crash.

Isi notifikasi **bukan** rahasia, jadi tidak memakai secure storage. Token tetap
hanya di `flutter_secure_storage`.

### 9.3 Badge

`BadgeService.setCount(n)` membungkus `AppBadgePlus`:

1. `isSupported()` — bila launcher tidak mendukung, tidak ada yang dilakukan;
2. `updateBadge(n)` — angka pada ikon aplikasi;
3. semua kegagalan platform ditelan (`on Object`) agar tidak terlihat pengguna.

Badge di dalam aplikasi memakai widget `Badge` Material 3 pada ikon lonceng di
`HomePage`, dengan angka yang sama.

### 9.4 Suara notifikasi

| Lapis | Berkas | Catatan |
|---|---|---|
| Sumber aset | `assets/mixkit-digital-quick-tone-2866.wav` | 227 KB, PCM 16-bit 44,1 kHz stereo; dideklarasikan di `pubspec.yaml` |
| Resource Android | `android/app/src/main/res/raw/campus_notif.wav` | Salinan berkas yang sama; **wajib**, karena Android hanya memutar suara dari resource native |
| Konstanta | `kNotificationSoundResource = 'campus_notif'` | Dipakai `UriAndroidNotificationSound(...)` |
| Channel | `kAnnouncementChannel` id `pengumuman_v2` | `playSound: true`, `importance: high` |

Channel memakai id baru (`pengumuman_v2`) karena setelan channel Android tidak
bisa diubah setelah dibuat. Payload dari backend harus memakai
`android.notification.channel_id = pengumuman_v2`; kalau tidak, Android memakai
channel lain dan suara kustom tidak terdengar.

## 10. Guard route

```mermaid
flowchart TD
  A["redirect(context, state)"] --> B{"auth.isLoading<br/>&& !auth.hasValue?"}
  B -- ya --> C["return null<br/>(tunggu pembacaan token)"]
  B -- tidak --> D{"loggedIn =<br/>auth.value != null"}
  D --> E{"atLogin =<br/>matchedLocation == '/login'"}
  E -- "!loggedIn && !atLogin" --> F["→ /login"]
  E -- "loggedIn && atLogin" --> G["→ /"]
  E -- lainnya --> H["return null<br/>(lanjutkan)"]
```

| Situasi | `auth.value` | Lokasi sekarang | Hasil |
|---|---|---|---|
| Aplikasi baru dibuka, token masih dibaca | `null`, `isLoading` | apa pun | Tetap (tidak diarahkan) — mencegah kedipan ke `/login` |
| Belum login | `null` | `/` | Pindah ke `/login` |
| Belum login | `null` | `/pengumuman/3` | Pindah ke `/login` (deep link ditahan sampai login) |
| Sudah login | `AuthSession` | `/login` | Pindah ke `/` |
| Sudah login | `AuthSession` | `/pengumuman/3` | Tetap |
| Logout / refresh mati | `null` | `/` | Pindah ke `/login` |

`refreshListenable` berupa `_AuthRefresh`, `ChangeNotifier` yang berlangganan
`authStateProvider` lewat `ref.listen`. Router dibuat **sekali**; perubahan sesi
hanya memicu evaluasi ulang `redirect`, bukan membuat router baru (membuat
router baru akan menghapus riwayat navigasi dan memutus deep link yang sedang
diproses).

## 11. Model state

### Sesi: `AsyncValue<AuthSession?>`

| State | Arti | Yang tampil |
|---|---|---|
| `AsyncLoading` tanpa value | Token sedang dibaca dari secure storage | Indikator loading di beranda; guard tidak mengambil keputusan |
| `AsyncData(null)` | Belum login | `/login` |
| `AsyncData(session)` | Sesi aktif | Beranda |
| `AsyncError` tanpa value | Pembacaan storage gagal | `_ErrorView` + tombol "Coba lagi" (`ref.invalidate`) |
| `AsyncError` dengan value | Login gagal, sesi lama tetap | Pesan error di form login |

### Notifikasi: `PushState`

| Field | Arti | Dipakai UI |
|---|---|---|
| `started` | `PushController.start()` sudah berjalan | Tidak langsung |
| `permissionGranted` | Izin notifikasi diberikan (atau `provisional` di iOS) | Baris "Izin notifikasi" |
| `token` | Token FCM utuh | **Tidak** — hanya `maskedToken` |
| `registeredOnBackend` | `POST /devices` dijawab 2xx | Baris "Laporan token ke backend" |
| `subscribedTopic` | Langganan `pengumuman-kampus` aktif | Baris "Topik" |
| `lastRoute` | Rute terakhir yang dibuka dari notifikasi | Baris "Deep link terakhir" |
| `note` | Penjelasan kegagalan yang bisa dibaca manusia | Teks merah di kartu |

## 12. Keamanan berlapis

| Lapis | Kendali | Berkas |
|---|---|---|
| Penyimpanan | Hanya `flutter_secure_storage`; tidak ada `SharedPreferences` di seluruh proyek | `data/token_store.dart` |
| Akses token | Satu pintu (`TokenStore`); tidak ada kode lain yang meng-import plugin secure storage | `data/token_store.dart` |
| Tampilan | `maskSecret()` untuk semua token (`abcd1234••••wxyz`); nilai ≤ 12 karakter disamarkan seluruhnya | `data/masking.dart` |
| Log | Hanya `messageId` yang di-`debugPrint` di handler background; tidak ada `print` token | `messaging/firebase_bootstrap.dart` |
| Error | `friendlyApiMessage()` menerjemahkan error teknis; `DioException` mentah tidak pernah dirender | `data/api_errors.dart` |
| Proses terpisah | Handler background `@pragma('vm:entry-point')` tidak menyentuh `BuildContext`, Riverpod, atau router | `messaging/firebase_bootstrap.dart` |
| Repositori | `google-services.json` dan `.secrets/` di-`.gitignore` | `.gitignore` |
| Sesi mati | Refresh gagal → `clear()` + `forceLogout()` | `data/api_client.dart`, `providers/auth_provider.dart` |

## 13. Keputusan desain dan alasannya

| Keputusan | Alternatif yang ditolak | Alasan |
|---|---|---|
| `TokenStore` sebagai satu-satunya pintu token | Memanggil `FlutterSecureStorage` langsung di repository | Satu tempat untuk diaudit; mudah diganti fake saat test |
| Parsing payload sebagai fungsi murni | Method di dalam `PushService` | Bisa diuji tanpa platform channel Firebase (11 test) |
| Navigasi lewat callback `onRoute` | `BuildContext` di dalam service | Service tetap bisa dipakai dari isolate/luar widget tree |
| `addPostFrameCallback` sebelum `start()` | Memanggil `start()` di `main()` sebelum `runApp` | `getInitialMessage()` butuh router yang sudah terpasang |
| Router tunggal + `refreshListenable` | Membuat `GoRouter` baru setiap status login berubah | Menjaga riwayat navigasi dan deep link yang sedang diproses |
| `bootstrapFirebase()` menangkap semua error | Membiarkan `Firebase.initializeApp()` melempar | Aplikasi tetap bisa dipakai (login, navigasi) tanpa FCM |
| Banner foreground manual | Mengandalkan sistem | Android tidak menampilkan notifikasi FCM saat aplikasi foreground |
| Channel dibuat eksplisit | Mengandalkan channel otomatis | Sejak Android 8, `importance` hanya berlaku saat channel dibuat |
| `POST /devices` gagal = `false`, bukan exception | Melempar error ke UI | Token tetap sah di sisi Firebase; hanya laporan backend yang tertunda |
| Mock auth di repository | Hard-code token di provider | Titik ganti ke Firebase Auth jelas dan tidak menyentuh UI |

## 14. Batasan arsitektur yang diketahui

| Batasan | Dampak | Cara menutup |
|---|---|---|
| `AuthRepository` mock hanya dipakai bila Firebase belum siap | Tanpa `google-services.json`, login tidak menyentuh Firebase | Letakkan berkas konfigurasi; implementasi Firebase sudah tersedia |
| `kApiBaseUrl` masih domain contoh | `POST /devices` tidak pernah berhasil; `registeredOnBackend` selalu `false` | Isi base URL backend nyata di `lib/data/api_client.dart` |
| Refresh token tidak dirotasi | Server dengan rotasi refresh akan menolak token lama pada refresh kedua | Simpan refresh baru yang dikembalikan `auth.refresh()` |
| `AuthExpiredException` didefinisikan tetapi tidak pernah dilempar | Pesan "Sesi berakhir" hanya muncul dari pemetaan status 401 | Lempar exception ini dari lapisan yang tahu sesi sudah mati, bila diperlukan |
| `PushState.copyWith` tidak bisa mengosongkan `note` | Catatan error lama bisa bertahan setelah kondisi pulih | Tambahkan penanda `clearNote` atau pakai sentinel value |
| `TokenStore.clear()` memakai `deleteAll()` | Menghapus semua kunci milik plugin, bukan hanya tiga kunci sesi | Ganti dengan `delete` per kunci bila kelak ada data lain di storage yang sama |
| Tidak ada validasi token saat aplikasi dibuka | Token mati tetap dianggap sesi aktif sampai ada request 401 | Panggil endpoint ringan (mis. `GET /me`) di `AuthNotifier.build()` |
| Badge bergantung pada launcher | Hanya launcher yang didukung ShortcutBadger yang menampilkan angka; Pixel/Infinix XOS hanya titik | Tidak bisa dipaksa dari aplikasi; angka di lonceng aplikasi tetap akurat |
| Channel `pengumuman_v2` berbeda dari payload lama | Payload `channel_id: pengumuman` memakai channel lama (tanpa suara kustom) | Perbarui backend/Console/`tools/send_fcm.py` |
| Handler background menulis penyimpanan tanpa sinkronisasi | Sangat jarang: tulisan bersamaan dengan UI bisa saling menimpa | Terima risiko ini; data hanya 50 entri dan bukan data kritis |
| Notifikasi yang diketuk dari panel sistem langsung dihapus dari daftar | Pengguna tidak melihatnya lagi di `/notifikasi` | Disengaja: diketuk berarti sudah dibaca |
| Belum ada pengujian di perangkat untuk fitur baru | Suara, badge, dan ikon belum diverifikasi di HP/emulator | Jalankan prosedur di [`uji-fcm.md`](uji-fcm.md) lalu simpan tangkapan layar |
| FCM memakai API deprecated (`getToken`, `onTokenRefresh`) | Peringatan analyzer ditekan dengan `// ignore:` | Migrasi ke `register()` / `onRegistered` (FID) — lihat [`ai-challenge.md`](ai-challenge.md) |
| Uji perangkat hanya Android 14 | Perilaku iOS (Keychain, APNs) belum diverifikasi | Perlu perangkat/emulator iOS dan APNs key |

## 15. Peta cepat "saya mau mengubah X"

| Kebutuhan | Berkas yang disentuh |
|---|---|
| Menambah layar baru | `lib/routes.dart`, `lib/providers/app_router.dart`, `lib/pages/` |
| Menambah tujuan deep link baru | `lib/routes.dart` + payload dari backend |
| Mengganti backend | `kApiBaseUrl` di `lib/data/api_client.dart` |
| Autentikasi nyata | `lib/data/auth_repository.dart` |
| Menambah topik notifikasi | `lib/messaging/push_service.dart` (`kCampusTopic`) + `PushController.toggleTopic` |
| Mengubah tampilan status | `lib/pages/home_page.dart` (`_PushCard`) |
| Menambah data yang dilaporkan ke backend | `lib/data/device_repository.dart` + kontrak di README |
| Mengubah suara notifikasi | Ganti `assets/mixkit-digital-quick-tone-2866.wav`, salin ke `android/app/src/main/res/raw/campus_notif.wav` |
| Mengubah ikon aplikasi | `assets/icon/app_icon*.png` lalu `dart run flutter_launcher_icons` |
| Mengubah tampilan daftar notifikasi | `lib/pages/notifications_page.dart` |
| Mengubah arti "dibaca" | `NotificationCenter.markRead` / `markAllRead` di `lib/providers/notification_providers.dart` |
| Mengubah sumber login | `FirebaseAuthRepository` di `lib/data/auth_repository.dart` |
