# Panduan pengembangan

Panduan untuk menjalankan, mengubah, dan menguji proyek ini. Untuk memahami
desainnya lebih dulu, baca [`arsitektur.md`](arsitektur.md).

## 1. Prasyarat

| Kebutuhan | Versi / catatan |
|---|---|
| Flutter SDK | Diuji pada **3.47.7** (stable), Dart **3.13.5** |
| Batasan SDK di `pubspec.yaml` | `sdk: ^3.13.5` |
| Perangkat Android | Emulator dengan **Google Play Services** atau HP fisik; tanpa Play Services `getToken()` mengembalikan `null` |
| Java (Gradle) | JDK 17 (dipakai `sourceCompatibility`/`jvmTarget` 17) |
| Python (opsional) | Untuk `tools/send_fcm.py`: `requests`, `google-auth`. Alternatif tanpa Python: `tools/send_fcm.ps1` (butuh `openssl` + `curl`) |
| Firebase | Project dengan aplikasi Android `com.horoboy.campusnotif` |

Dependensi runtime (dari `pubspec.yaml`):

| Paket | Versi | Dipakai untuk |
|---|---|---|
| `dio` | ^5.11.1 | HTTP + interceptor |
| `firebase_core` | ^5.1.0 | Inisialisasi Firebase |
| `firebase_messaging` | ^17.0.1 | Token, pesan, topik |
| `flutter_local_notifications` | ^22.3.3 | Banner saat foreground |
| `flutter_riverpod` | ^3.4.3 | State management + DI |
| `flutter_secure_storage` | ^11.2.0 | Penyimpanan token |
| `go_router` | ^18.1.1 | Navigasi + guard |
| `flutter_lints` (dev) | ^6.0.0 | Aturan lint (`analysis_options.yaml`) |

## 2. Perintah harian

```bash
flutter pub get          # pasang dependensi
flutter analyze          # harus: No issues found!
flutter test             # harus: All tests passed! (55 test)
flutter test test/payload_test.dart            # satu berkas
flutter test --plain-name "401"                # satu test berdasarkan nama
flutter run              # jalankan di perangkat/emulator
flutter run -d chrome    # UI tetap jalan, FCM tidak aktif di web
flutter build apk --debug
dart run flutter_launcher_icons   # generate ulang ikon setelah ganti assets/icon/
```

Catatan: `analysis_options.yaml` mengecualikan `build/**`, `android/**`, dan
`web/**` dari analisis.

## 3. Struktur folder

```text
campusnotif/
├── lib/
│   ├── main.dart              # bootstrap + MaterialApp.router
│   ├── routes.dart            # konstanta path
│   ├── data/                  # sumber data, tanpa UI
│   ├── providers/             # Riverpod: state, DI, router
│   ├── messaging/             # FCM + local notification + parsing payload
│   └── pages/                 # widget layar
├── test/                      # 55 test
├── tools/
│   ├── send_fcm.py            # pengirim notifikasi uji (FCM HTTP v1)
│   ├── send_fcm.ps1           # versi PowerShell (tanpa dependensi Python)
│   └── make_app_icon.ps1      # generator ikon aplikasi
├── assets/
│   ├── mixkit-digital-quick-tone-2866.wav   # sumber suara notifikasi
│   └── icon/                  # sumber ikon (app_icon, foreground)
├── screenshots/               # bukti 7 tangkapan layar
├── docs/                      # dokumentasi ini
└── android/app/
    ├── build.gradle.kts       # plugin google-services bersyarat
    ├── src/main/res/raw/campus_notif.wav    # suara untuk Android
    ├── src/main/res/mipmap-*/ic_launcher.*  # ikon hasil generate
    └── google-services.json   # TIDAK di-commit
```

## 4. Konfigurasi Firebase

1. Buat project di [Firebase Console](https://console.firebase.google.com/).
2. Tambahkan aplikasi Android dengan package name **`com.horoboy.campusnotif`**
   (harus sama dengan `applicationId` di `android/app/build.gradle.kts`).
3. Unduh `google-services.json` → letakkan di `android/app/google-services.json`.
4. Aktifkan **Authentication → Sign-in method → Email/Password**, lalu buat akun
   uji di **Authentication → Users → Add user**. Tanpa langkah ini login akan
   gagal dengan pesan "Login email/kata sandi belum diaktifkan…".
5. Build ulang (`flutter run`). Plugin `com.google.gms.google-services`
   diterapkan **otomatis** karena `build.gradle.kts` memeriksa keberadaan berkas
   tersebut:

   ```kotlin
   if (file("google-services.json").exists()) {
       apply(plugin = "com.google.gms.google-services")
   }
   ```

6. Untuk mengirim notifikasi dari CLI, unduh service account
   (Project settings → Service accounts → Generate new private key) dan simpan
   sebagai `.secrets/service-account.json`.

**Jangan commit** `google-services.json` maupun `.secrets/` — keduanya sudah
ada di `.gitignore`.

## 5. Menjalankan tanpa Firebase

Proyek tetap bisa dijalankan tanpa `google-services.json`. Perilakunya:

| Bagian | Tanpa Firebase |
|---|---|
| Login, guard route, beranda | Berjalan normal (auth **mock**, bukan Firebase) |
| `bootstrapFirebase()` | Mengembalikan `FirebaseBootstrap.notConfigured(...)` |
| `authRepositoryProvider` | Memakai `MockAuthRepository` |
| `PushController.start()` | Berhenti lebih awal; kartu status menampilkan alasan |
| `POST /devices`, token, topik | Tidak dijalankan |
| Kotak masuk, badge, halaman `/notifikasi` | Tetap berfungsi (uji lewat tombol notifikasi uji) |
| Test widget | Memakai mode ini (`FirebaseBootstrap.notConfigured('test')`) |

Ini juga alasan `android/app/build.gradle.kts` tidak menerapkan plugin
google-services secara unconditional: tanpa berkas konfigurasi, build akan
gagal total dan aplikasi tidak bisa dijalankan sama sekali.

## 6. Konvensi kode

Gaya yang sudah dipakai di seluruh proyek — ikuti agar perubahan konsisten:

| Konvensi | Contoh |
|---|---|
| Komentar dan pesan UI berbahasa Indonesia | `'Sesi berakhir. Silakan login ulang.'` |
| Tipe ditulis eksplisit, termasuk argumen generic | `final List<String> segments = ...`, `Dio.get<dynamic>` |
| `final`/`const` dipakai maksimal | `const SizedBox(height: 16)` |
| Anggota privat untuk helper UI | `_SessionView`, `_PushCard`, `_Row`, `_ErrorView` |
| Named parameter untuk API dengan > 2 argumen | `showLocalNotification(title:, body:, route:)` |
| Dokumentasi `///` menjelaskan **mengapa**, bukan mengulang nama | Lihat `initFcmToken`, `buildApiClient` |
| Path hanya dari `Routes` | `context.go(Routes.announcement('3'))` |
| Token hanya lewat `maskSecret()` | `push.maskedToken`, `session.maskedAccess` |
| Penanda sengaja untuk analyzer | `// ignore: deprecated_member_use` disertai alasan di komentar |

Aturan keras (melanggar berarti bug, bukan selera):

1. Jangan menyimpan token di `SharedPreferences`, file, atau state yang
   dirender.
2. Jangan mencetak token/payload penuh ke log.
3. Jangan memakai `BuildContext` di `messaging/`.
4. Jangan membuat `GoRouter` baru di dalam `build`.
5. Jangan menambah `await` di `PushController.start()` sebelum
   `addPostFrameCallback` — urutannya sudah disengaja.

## 7. Resep perubahan

### 7.1 Mengganti base URL backend

```dart
// lib/data/api_client.dart
const String kApiBaseUrl = 'https://api.kampus.ac.id';
```

Tidak ada perubahan lain. `apiClientProvider` otomatis memakai nilai baru, dan
`DeviceRepository` mengikuti. Setelah backend hidup, `POST /devices` akan
membuat baris "Laporan token ke backend" berubah menjadi
`POST /devices berhasil`.

### 7.2 Login Firebase Authentication (sudah terpasang)

Implementasi produksi sudah ada di `FirebaseAuthRepository`
(`lib/data/auth_repository.dart`). Yang perlu dilakukan hanya menyiapkan
Firebase:

1. Taruh `google-services.json` di `android/app/`.
2. Firebase Console → **Authentication → Sign-in method → Email/Password**:
   aktifkan.
3. **Authentication → Users → Add user**: buat akun uji.
4. `flutter run`. `firebaseReadyProvider` bernilai `true`, sehingga
   `authRepositoryProvider` memakai `FirebaseAuthRepository`.

Bila langkah 1 belum dilakukan, aplikasi tetap jalan dengan
`MockAuthRepository` (email mengandung `@`, sandi ≥ 6 karakter).

Bentuk `AuthSession` sengaja dibuat menyerupai respons Firebase Auth, sehingga
`AuthNotifier`, `TokenStore`, `api_client.dart`, router, dan seluruh UI tidak
perlu berubah saat sumber auth diganti.

Catatan: `refresh()` memakai `user.getIdToken(true)` dan mengabaikan argumen
`refreshToken` karena Firebase menyimpan sesinya sendiri. Bila kelak backend
memutar refresh token, sesuaikan `save(...)` di `api_client.dart` (lihat
[`arsitektur.md`](arsitektur.md) bagian 6).

### 7.3 Menambah layar baru

1. Tambahkan path di `lib/routes.dart`:

   ```dart
   static const String profile = '/profil';
   ```

2. Buat halaman di `lib/pages/profile_page.dart`.
3. Daftarkan di `app_router.dart`:

   ```dart
   GoRoute(
     path: Routes.profile,
     builder: (context, state) => const ProfilePage(),
   ),
   ```

4. Guard otomatis berlaku: pengguna yang belum login akan diarahkan ke
   `/login`.

### 7.4 Menambah tujuan deep link baru

1. Tambahkan pola di `Routes` (mis. `/nilai/:semester`).
2. Daftarkan `GoRoute`-nya.
3. Kirim `data.route` yang sesuai dari backend/Console.
4. Bila butuh parsing khusus, tambahkan fungsi murni di
   `lib/messaging/payload.dart` dan tulis test-nya lebih dulu.

Tidak perlu mengubah `PushService`: ia hanya meneruskan string rute.

### 7.5 Menambah topik notifikasi

```dart
// lib/messaging/push_service.dart
const String kCampusTopic = 'pengumuman-kampus';
const String kGradesTopic = 'nilai-mahasiswa';
```

Tambahkan `subscribeGradesTopic()` mengikuti pola yang ada, panggil dari
`PushController.start()`, dan tampilkan statusnya di `PushState` bila perlu
bukti. Jangan lupa membuat channel terpisah bila importance-nya berbeda.

### 7.6 Mengubah saluran/kanal notifikasi

`kAnnouncementChannel` (`id: 'pengumuman_v2'`) dipakai di dua tempat: pembuatan
channel dan `showLocalNotification`. Bila `id` berubah, sesuaikan pula
`android.notification.channel_id` pada payload yang dikirim backend
(`tools/send_fcm.py` → `CHANNEL_ID`).

**Penting:** setelan channel Android bersifat *immutable*. Mengubah suara pada
`id` yang sama **tidak** berefek pada perangkat yang sudah pernah membuat
channel itu. Kalau perlu mengubah suara, buat `id` baru (mis.
`pengumuman_v3`) dan perbarui `CHANNEL_ID` di skrip/backend.

### 7.7 Mengganti suara notifikasi

1. Ganti berkas `assets/mixkit-digital-quick-tone-2866.wav` (atau tambahkan
   berkas baru dan perbarui daftar `assets:` di `pubspec.yaml`).
2. Salin berkas yang sama ke `android/app/src/main/res/raw/campus_notif.wav`.
   Nama berkas di `res/raw` harus **huruf kecil, tanpa tanda hubung**, dan tanpa
   ekstensi pada rujukannya.
3. Bila nama resource berubah, sesuaikan
   `kNotificationSoundResource` di `lib/messaging/push_service.dart`.
4. Karena channel lama tidak bisa diubah, ganti id channel (lihat 7.6) dan
   perbarui `CHANNEL_ID` di `tools/send_fcm.py`.
5. `flutter run`, lalu pakai tombol **"Tampilkan notifikasi uji"** di beranda
   untuk mendengar suara tanpa menunggu FCM.

### 7.8 Mengganti ikon aplikasi

1. Ganti `assets/icon/app_icon.png` (1024×1024, latar penuh) dan
   `assets/icon/app_icon_foreground.png` (1024×1024, latar transparan, isi di
   dalam ±66% area tengah).
2. Jalankan:

   ```bash
   dart run flutter_launcher_icons
   ```

3. Konfigurasinya ada di blok `flutter_launcher_icons` pada `pubspec.yaml`
   (`android: "ic_launcher"`, `adaptive_icon_background: "#0B6E4F"`).
4. Ikon bisa dibuat ulang dari nol dengan
   `powershell -ExecutionPolicy Bypass -File tools/make_app_icon.ps1`.

Hasilnya: `android/app/src/main/res/mipmap-*/ic_launcher.png` dan
`mipmap-anydpi-v26/ic_launcher.xml` (adaptive icon). Hapus aplikasi lama dari
perangkat agar launcher memuat ulang ikon.

### 7.9 Mengubah perilaku kotak masuk notifikasi

Semua perilaku "dibaca" terpusat di `NotificationCenter`
(`lib/providers/notification_providers.dart`):

| Ingin | Ubah |
|---|---|
| Entri tetap tampil setelah dibaca | Tambahkan field `read` pada `AppNotification` dan filter di halaman |
| Batas jumlah entri | `NotificationStore.maxEntries` |
| Menyimpan arsip terpisah | Tambahkan kunci kedua di `NotificationStore` |
| Angka badge berbeda dari jumlah entri | Ubah `NotificationCenter._syncBadge()` |

Jangan menambah penghitung badge sendiri: angka badge selalu
`state.length` agar tidak ada dua sumber kebenaran.

## 8. Menulis dan menjalankan test

Tiga jenis test yang sudah ada, dan kapan memakai masing-masing:

| Jenis | Cocok untuk | Contoh |
|---|---|---|
| Test murni | Parsing payload, masking, aturan route | `test/payload_test.dart` |
| Test unit dengan fake dependency | Interceptor Dio, notifier auth | `test/api_client_test.dart`, `test/auth_test.dart` |
| Widget test | Guard route, alur login, render status | `test/auth_test.dart` |

### 8.1 Menyuntikkan `TokenStore` palsu

`TokenStore` punya konstruktor opsional `storage`, tetapi cara yang dipakai
proyek ini adalah **subclass** dan override method-nya:

```dart
class FakeTokenStore extends TokenStore {
  String? access;
  int clearCount = 0;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<void> clear() async {
    access = null;
    clearCount++;
  }
}
```

Lalu suntikkan lewat `ProviderScope`/`ProviderContainer`:

```dart
ProviderScope(
  overrides: [tokenStoreProvider.overrideWithValue(FakeTokenStore())],
  child: const CampusNotifyApp(
    firebase: FirebaseBootstrap.notConfigured('test'),
  ),
);
```

### 8.2 Menguji HTTP tanpa jaringan

Gunakan `ScriptedAdapter` sebagai `httpClientAdapter`:

```dart
final dio = buildApiClient(
  store: store,
  auth: _RenewingRepository('access-baru'),
  onSessionExpired: () async => sessionExpiredCalls++,
)..httpClientAdapter = ScriptedAdapter(validToken: 'access-baru');
```

Adapter mengembalikan 401 untuk token selain `validToken` dan 200 untuk token
yang benar, sehingga alur 401 → refresh → retry bisa diuji utuh tanpa server.

### 8.3 Aturan test di proyek ini

1. Setiap bug perilaku yang diperbaiki **harus** mendapat test yang gagal
   sebelum perbaikan.
2. Nama test berupa kalimat perilaku, bukan nama method:
   `'refresh ditolak server -> sesi dibersihkan (paksa login ulang)'`.
3. Jangan memakai `sleep`; pakai jeda buatan repository yang sudah ada atau
   `pumpAndSettle`.
4. Widget test tidak boleh menyentuh Firebase; gunakan
   `FirebaseBootstrap.notConfigured`.
5. Jalankan `flutter analyze` **dan** `flutter test` sebelum commit.

### 8.4 Menambah test baru

```bash
# buat berkas test/foo_test.dart, lalu:
flutter test test/foo_test.dart
```

Pastikan jumlah test di [`referensi-kode.md`](referensi-kode.md) dan README
diperbarui bila jumlahnya berubah.

## 9. Troubleshooting

| Gejala | Penyebab umum | Tindakan |
|---|---|---|
| Build gagal: `No matching client found for package name` | `google-services.json` untuk package lain | Unduh ulang dengan package `com.horoboy.campusnotif` |
| Aplikasi jalan tapi `FCM token: -` | Tanpa Play Services, atau Firebase belum siap | Pakai emulator ber-Play Store / HP fisik; cek pesan di kartu status |
| "Laporan token ke backend: POST /devices belum berhasil" | `kApiBaseUrl` masih domain contoh | Ganti base URL (resep 7.1) |
| Notifikasi tidak masuk sama sekali | Target campaign "User segment" (Analytics mati) | Gunakan target **Topic** `pengumuman-kampus` — lihat [`uji-fcm.md`](uji-fcm.md) |
| Notifikasi muncul, klik mendarat di beranda | `data.route` tidak terkirim | Isi custom data `route` + `id`; atau pakai `tools/send_fcm.py` |
| Banner muncul dua kali di background | Handler background ikut menampilkan notifikasi | Hapus pemanggilan `show()` di handler background |
| Klik notifikasi saat terminated tidak navigasi | `getInitialMessage()` selesai sebelum router siap | Pastikan `start()` tetap dipanggil di `addPostFrameCallback` |
| `flutter analyze` mengeluh `deprecated_member_use` | `getToken`/`onTokenRefresh` | Sudah ditandai `// ignore:`; jangan hapus tanpa migrasi ke FID |
| Gradle gagal di Windows: `java.io.tmpdir` | Folder temp sesi sebelumnya | `cd android; gradlew.bat --stop`, lalu build ulang |
| `flutter test` gagal karena platform channel | Test menyentuh secure storage/Firebase asli | Override provider dengan fake, pakai `notConfigured` |
| Izin notifikasi tidak pernah muncul | Sudah ditolak permanen sebelumnya | Pengaturan aplikasi → Notifikasi → aktifkan manual |
| Login selalu "Email atau kata sandi tidak valid" padahal akun benar | Firebase belum siap sehingga memakai `MockAuthRepository` | Cek teks catatan di layar login; taruh `google-services.json` bila seharusnya Firebase |
| Login gagal: "…belum diaktifkan di Firebase Console" | Provider Email/Password belum aktif | Authentication → Sign-in method → aktifkan Email/Password |
| Login gagal: "Email belum terdaftar" | User belum dibuat | Authentication → Users → Add user |
| Notifikasi berbunyi nada default, bukan suara kustom | Payload memakai `channel_id` lama (`pengumuman`) atau channel sudah terlanjur dibuat | Pakai `pengumuman_v2` (lihat resep 7.6/7.7); hapus aplikasi lalu pasang ulang |
| Suara tetap tidak ada padahal channel benar | `res/raw/campus_notif.wav` tidak ada / nama resource salah | Pastikan berkas ada dan `kNotificationSoundResource` = `campus_notif` |
| Angka badge tidak muncul di ikon | Launcher tidak mendukung badge angka (ShortcutBadger) | Uji di Samsung/MIUI/Oppo/Vivo/Huawei; Pixel & Infinix XOS hanya menampilkan titik. Angka di lonceng aplikasi tetap benar |
| Badge tertinggal setelah notifikasi dibaca | Aplikasi belum menerima perubahan state | Buka `/notifikasi` (otomatis `reload()`) atau tarik ke bawah; aplikasi juga membaca ulang saat kembali aktif |
| Ikon aplikasi masih ikon Flutter | `flutter_launcher_icons` belum dijalankan / cache launcher | Jalankan `dart run flutter_launcher_icons`, hapus aplikasi lama, pasang ulang |
| Daftar notifikasi kosong padahal ada notifikasi | Aplikasi dibuka lewat notifikasi (entri langsung dianggap dibaca), atau belum ada notifikasi saat foreground | Kirim notifikasi selagi aplikasi terbuka, atau pakai tombol "Tampilkan notifikasi uji" |
| Notifikasi masuk tapi lonceng tidak bertambah (aplikasi sempat di background) | Daftar di memori tertinggal dari penyimpanan yang ditulis handler background | Sudah ditangani: `AppLifecycleListener(onResume:)` dan `initState` halaman `/notifikasi` memanggil `reload()` |
| Notifikasi sama sekali tidak masuk setelah `adb shell am force-stop` | `force-stop` menaruh aplikasi di *stopped state*; Android menahan FCM sampai aplikasi dibuka manual | Uji state terminated dengan `am kill`/tutup dari recents, atau buka aplikasi dulu setelah `force-stop` |
| Suara tidak terdengar padahal channel benar | Mode dering perangkat **Vibrate/Silent** mematikan `STREAM_NOTIFICATION` | Naikkan volume Notifikasi (Setelan → Suara) dan pastikan mode dering **Ring**; cek `adb shell dumpsys audio` → bagian `STREAM_NOTIFICATION` harus `Muted: false` |
| Login/daftar akun gagal: `CONFIGURATION_NOT_FOUND` | Authentication belum pernah diinisialisasi di project Firebase | Buka Firebase Console → Authentication → **Get started**, lalu aktifkan Email/Password. Tidak bisa diaktifkan lewat Admin API sebelum langkah ini |
| Sesi lama berisi `mock-acc…` setelah memasang build baru | Data aplikasi lama ikut terpakai saat `adb install -r` | Tekan **Keluar** di beranda, atau `adb shell pm clear com.horoboy.campusnotif` |

## 10. Checklist sebelum commit

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test` → semua lulus
- [ ] Tidak ada token/payload di log (`Select-String -Pattern "print\(" lib\` di PowerShell)
- [ ] Path baru memakai konstanta `Routes`
- [ ] Token yang dirender melewati `maskSecret()`
- [ ] Angka badge berasal dari `notificationsProvider.length` (bukan penghitung baru)
- [ ] Berkas di `assets/` dan `res/raw/` sinkron bila suara diganti
- [ ] Ikon di-generate ulang bila `assets/icon/` berubah
- [ ] Dokumentasi terkait diperbarui (`README.md` bila fitur berubah, dokumen
      di `docs/` bila arsitektur atau kontrak berubah)
- [ ] `google-services.json` dan `.secrets/` tidak ikut ter-*stage*
