# Campus Notify

Aplikasi Flutter untuk mempraktikkan **autentikasi**, **penyimpanan token yang
aman**, dan **Firebase Cloud Messaging (FCM)** pada satu alur yang utuh: login →
token aman + refresh otomatis → notifikasi push → deep link ke halaman
pengumuman, terbukti pada ketiga app state.

## Fitur utama

- Login dengan **Firebase Authentication** (email + kata sandi) dan guard route:
  belum login selalu diarahkan ke `/login`. Bila `google-services.json` belum
  ada, aplikasi otomatis memakai auth mock agar tetap bisa didemokan.
- Token (access + refresh) hanya disimpan di `flutter_secure_storage`.
- Dio interceptor: menyisipkan `Authorization: Bearer <access>` dan saat 401
  menukar refresh token **satu kali** lalu mengulang request. Bila refresh ikut
  mati, sesi dibersihkan dan pengguna dipaksa login ulang.
- FCM: izin runtime, `getToken` + `onTokenRefresh` dilaporkan ke `POST /devices`,
  langganan topik `pengumuman-kampus`.
- Logout melepas perangkat (`DELETE /devices`) dan menghentikan langganan topik
  **sebelum** token dihapus, agar backend berhenti mengirim notifikasi personal
  ke perangkat yang sudah keluar; login berikutnya memasang FCM lagi.
- Notifikasi gabungan `notification` + `data`, klik membuka `/pengumuman/:id`
  pada state foreground, background, dan terminated.
- **Kotak masuk notifikasi** (`/notifikasi`): notifikasi yang masuk masuk ke
  daftar; begitu dibaca, entri langsung hilang dari daftar.
- **Badge angka** pada ikon aplikasi dan pada ikon lonceng di AppBar, selalu
  sama dengan jumlah notifikasi yang belum dibaca.
- **Suara notifikasi kustom** dari berkas aset
  (`assets/mixkit-digital-quick-tone-2866.wav` → `res/raw/campus_notif.wav`).
- **Ikon aplikasi non-default**: lonceng + titik notifikasi, termasuk adaptive
  icon Android 8+.
- Banner foreground ditampilkan manual lewat `flutter_local_notifications`
  (sistem tidak menampilkannya sendiri saat aplikasi terbuka).
- Token selalu ditampilkan terpotong (`abcd1234••••wxyz`), tidak pernah utuh.

## Stack teknologi

| Teknologi | Kegunaan |
|---|---|
| Flutter / Dart | UI aplikasi mobile |
| Riverpod | State management, DI, `AsyncValue` |
| GoRouter | Navigasi, guard route, deep link |
| Dio | HTTP client + interceptor refresh token |
| firebase_auth | Login email + kata sandi (Firebase Authentication) |
| flutter_secure_storage | Penyimpanan access & refresh token |
| firebase_core + firebase_messaging | FCM: token, pesan, topik |
| flutter_local_notifications | Banner foreground + suara notifikasi kustom |
| shared_preferences | Kotak masuk notifikasi (bukan rahasia, jadi bukan secure storage) |
| app_badge_plus | Angka badge pada ikon aplikasi |
| flutter_launcher_icons (dev) | Generate ikon launcher + adaptive icon |


## Struktur

```text
lib/
├── main.dart                     # bootstrap Firebase + ProviderScope
├── routes.dart                   # konstanta path (dipakai router & FCM)
├── data/
│   ├── token_store.dart          # satu-satunya pintu token
│   ├── auth_repository.dart      # Firebase Auth + fallback mock + refresh
│   ├── api_client.dart           # Dio + interceptor 401 -> refresh -> retry
│   ├── api_errors.dart           # DioException -> pesan ramah
│   ├── device_repository.dart    # POST/DELETE /devices
│   ├── notification_store.dart   # kotak masuk notifikasi + KeyValueStore
│   ├── badge_service.dart        # angka badge pada ikon aplikasi
│   ├── relative_time.dart        # "5 mnt lalu" (fungsi murni)
│   └── masking.dart              # maskSecret()
├── providers/
│   ├── auth_provider.dart        # AuthNotifier, apiClientProvider, firebaseReady
│   ├── app_router.dart           # GoRouter + redirect guard
│   ├── notification_providers.dart # NotificationCenter + sinkron badge
│   └── push_providers.dart       # PushController + PushState
├── messaging/
│   ├── firebase_bootstrap.dart   # init Firebase + background handler top-level
│   ├── payload.dart              # routeFromMessage / idFromMessage (fungsi murni)
│   └── push_service.dart         # permission, token, 3 handler, topik, suara
└── pages/
    ├── login_page.dart
    ├── home_page.dart            # sesi + status notifikasi + lonceng badge
    ├── notifications_page.dart   # daftar notifikasi belum dibaca
    └── announcement_page.dart    # target deep link /pengumuman/:id

assets/
├── mixkit-digital-quick-tone-2866.wav   # sumber suara notifikasi
└── icon/                                # sumber ikon aplikasi

android/app/src/main/res/
├── raw/campus_notif.wav                 # salinan suara (wajib untuk Android)
└── mipmap-*/ic_launcher.*               # hasil flutter_launcher_icons
```

## Cara menjalankan

### 1. Prasyarat

- Flutter SDK (proyek ini diuji pada Flutter 3.47.7 / Dart 3.13.5).
- Perangkat Android dengan **Google Play Services** (emulator ber-Play Store
  atau HP fisik). Tanpa Play Services, `getToken()` mengembalikan `null`.

### 2. Konfigurasi Firebase

1. Buat project di [Firebase Console](https://console.firebase.google.com/).
2. Tambahkan aplikasi Android dengan package name **`com.horoboy.campusnotif`**
   (harus sama dengan `applicationId`).
3. Unduh `google-services.json`, taruh di `android/app/google-services.json`.
4. Plugin `com.google.gms.google-services` aktif **otomatis** bila berkas itu
   ada — lihat `android/app/build.gradle.kts`. Tanpa berkas tersebut aplikasi
   tetap bisa dibangun dan dijalankan, hanya FCM yang tidak aktif.
5. Aktifkan **Authentication → Sign-in method → Email/Password**.
6. Buat akun uji di **Authentication → Users → Add user** (mis.
   `mhs@polinema.ac.id` dengan kata sandi minimal 6 karakter). Akun inilah yang
   dipakai untuk login.

`google-services.json` dan `.secrets/` sudah di-`.gitignore` karena memuat
kredensial.

### 3. Build & jalankan

```bash
flutter pub get
flutter run
```

Login memakai **akun Firebase Authentication** yang dibuat pada langkah 6.
Bila `google-services.json` belum ada (Firebase tidak siap), aplikasi otomatis
memakai auth mock: email apa pun yang mengandung `@` dan kata sandi minimal
6 karakter. Status yang dipakai terlihat di layar login.

### 4. Mengirim notifikasi uji

Cara paling andal (payload persis, bisa diulang) memakai FCM HTTP v1:

```bash
# Sekali saja: Firebase Console -> Project settings -> Service accounts
# -> Generate new private key, simpan sebagai .secrets/service-account.json

python tools/send_fcm.py --id 3          # kirim ke topik pengumuman-kampus
python tools/send_fcm.py --id 3 --token <FCM_TOKEN>   # ke satu perangkat
```

Tanpa Python (Windows): `tools/send_fcm.ps1` mengirim payload yang sama memakai
`openssl` + `curl`.

```powershell
powershell -ExecutionPolicy Bypass -File tools/send_fcm.ps1 -Id 3
```

Alternatif lewat Firebase Console: Messaging → New campaign → **Firebase
Notification messages** → target **Topic** `pengumuman-kampus` → Additional
options: Android Notification Channel `pengumuman_v2`, custom data
`route=/pengumuman/3` dan `id=3`.

> Catatan penting: target **User segment** tidak berfungsi pada project ini
> karena Google Analytics tidak diaktifkan, sehingga audiens kosong dan
> campaign terkirim ke 0 perangkat. Gunakan **Topic**.

## Hasil pengujian tiga app state

Diuji pada **Infinix X6882, Android 14 (API 34)**, aplikasi
`com.horoboy.campusnotif`, channel `pengumuman_v2` (importance HIGH, suara
kustom `campus_notif`).

Payload yang dipakai untuk ketiga state:

```json
{
  "notification": { "title": "Jadwal kuliah berubah", "body": "Kelas Mobile pindah ke Ruang A2 jam 13.00" },
  "data": { "route": "/pengumuman/3", "id": "3" },
  "android": { "priority": "high", "notification": { "channel_id": "pengumuman_v2" } }
}
```

| State | Kondisi app sebelum kirim | Handler yang bekerja | Hasil | Bukti |
|---|---|---|---|---|
| Foreground | Aplikasi terbuka di layar | `FirebaseMessaging.onMessage` → banner lokal manual | Banner heads-up muncul; klik masuk `/pengumuman/9` | `02-foreground-banner.png`, `03-foreground-deeplink-id9.png` |
| Background | Ditekan Home (proses hidup) | `onMessageOpenedApp` | Banner sistem muncul di shade; klik membuka app di `/pengumuman/5` | `04-background-notification.png`, `05-background-deeplink-id5.png` |
| Terminated | Di-swipe dari recents (proses mati) | `getInitialMessage` | Notifikasi tetap masuk lewat `FlutterFirebaseMessagingBackgroundService`; klik membuka app **dari nol** langsung di `/pengumuman/3` | `06-terminated-notification.png`, `07-terminated-deeplink-id3.png` |

`id` sengaja dibedakan (9 / 5 / 3) agar terbukti tiap klik membawa payload dari
notifikasi yang benar, bukan tertinggal di halaman sebelumnya.

Bukti status runtime (token terpotong, izin, topik):
`screenshots/01-home-status-fcm.png`.

## Hasil pengujian otomatis

```bash
flutter analyze   # No issues found!
flutter test      # All tests passed! (55 test)
flutter build apk --debug   # Built build/app/outputs/flutter-apk/app-debug.apk
```

| Berkas | Cakupan |
|---|---|
| `test/auth_test.dart` | guard route, login valid/invalid, sesi setengah jadi dibersihkan, refresh sukses/gagal |
| `test/api_client_test.dart` | 401 → refresh sekali → retry sukses (2 request); refresh mati → 1 request + sesi dibersihkan |
| `test/payload_test.dart` | `routeFromMessage`, `idFromMessage`, `sanitizeRoute`, `maskSecret` |
| `test/notification_test.dart` | model notifikasi, `NotificationStore` (dedupe/batas data rusak), `NotificationCenter` + badge, `relativeTime`, `authMessageFor`, dan widget test "notifikasi dibaca → hilang dari daftar" |
| `test/push_test.dart` | `PushState.copyWith` (termasuk `null` yang mengosongkan `note`/`token`), `maskedToken`, `PushController.start`, dan `detach()` saat logout |

## Keamanan

- Token tidak pernah ditulis ke `SharedPreferences`, log, atau dirender utuh.
- Tidak ada `print`/`debugPrint` yang mencetak token (yang ada hanya id pesan
  dan jenis error).
- Kotak masuk notifikasi memakai `shared_preferences` karena isinya pengumuman,
  bukan kredensial; token tetap hanya di `flutter_secure_storage`.
- `google-services.json` dan `.secrets/` tidak masuk version control.
- Background handler berupa fungsi top-level `@pragma('vm:entry-point')` dan
  tidak menyentuh `BuildContext`, Riverpod, maupun router.

## Keterbatasan yang diketahui

- `kApiBaseUrl` masih domain contoh (`https://example-campus-api.test`), jadi
  `POST /devices` belum berhasil. Kontrak endpoint didokumentasikan di
  `lib/data/device_repository.dart`.
- Firebase menyimpan sesinya sendiri; perpanjangan token memakai
  `User.getIdToken(forceRefresh: true)`. Bila platform tidak mengekspos refresh
  token, `TokenStore` menyimpan penanda `firebase:getIdToken` (bukan rahasia).
- Angka badge pada ikon aplikasi bergantung pada launcher. Badge angka hanya bisa
  dipasang pada launcher yang didukung ShortcutBadger (Samsung, MIUI, Oppo, Vivo,
  Huawei/Honor, Sony, …); Pixel dan Infinix XOS hanya menampilkan titik dari
  notifikasi aktif. Angka pada lonceng di dalam aplikasi selalu akurat.
- Channel notifikasi berganti nama menjadi `pengumuman_v2` karena setelan
  channel Android tidak bisa diubah setelah dibuat (suara kustom butuh channel
  baru). Payload dari backend wajib memakai `channel_id: pengumuman_v2`.
- `getToken`/`onTokenRefresh` ditandai deprecated oleh `firebase_messaging` 17
  (arahan ke `register`/`onRegistered`), tetapi tetap dipakai karena Console
  masih menargetkan FCM registration token. Lihat `docs/`.

## Dokumentasi

| Berkas | Isi |
|---|---|
| [`docs/README.md`](docs/README.md) | Indeks dokumentasi + jalur baca yang disarankan |
| [`docs/arsitektur.md`](docs/arsitektur.md) | Peta lapisan, graf provider, alur login / refresh 401 / FCM / deep link, keputusan desain, batasan |
| [`docs/referensi-kode.md`](docs/referensi-kode.md) | Kontrak tiap berkas di `lib/`: kelas, fungsi, konstanta, invariant, test yang menguncinya |
| [`docs/panduan-pengembangan.md`](docs/panduan-pengembangan.md) | Prasyarat, perintah harian, konfigurasi Firebase, konvensi kode, resep perubahan, troubleshooting |
| [`docs/panduan-pengguna.md`](docs/panduan-pengguna.md) | Panduan layar login & beranda, arti tiap status, perilaku notifikasi tiga app state |
| [`docs/ai-challenge.md`](docs/ai-challenge.md) | Prompt, output awal AI, 9 error kompilasi yang ditemukan lewat `flutter analyze`, bagian yang ditolak dan alasannya |
| [`docs/ai-draft-raw.md`](docs/ai-draft-raw.md) | Draf AI mentah, disimpan apa adanya sebagai bukti |
| [`docs/uji-fcm.md`](docs/uji-fcm.md) | Prosedur uji tiga app state + dua jebakan Firebase Console yang membuat pengiriman gagal |
| [`docs/refleksi.md`](docs/refleksi.md) | Jawaban empat pertanyaan refleksi codelab |

## Refleksi singkat

Refresh token tidak boleh di `SharedPreferences` karena berkas itu tersimpan
sebagai XML biasa di penyimpanan aplikasi — bisa dibaca di perangkat yang sudah
di-root, ikut tersalin lewat backup, dan tidak terenkripsi oleh sistem.
`flutter_secure_storage` memakai Keystore (Android) / Keychain (iOS) sehingga
nilainya terikat ke perangkat dan tidak bisa dipindahkan begitu saja. Detail
lengkap ada di `docs/refleksi.md`.

