# Campus Notify

Aplikasi Flutter untuk mempraktikkan **autentikasi**, **penyimpanan token yang
aman**, dan **Firebase Cloud Messaging (FCM)** pada satu alur yang utuh: login →
token aman + refresh otomatis → notifikasi push → deep link ke halaman
pengumuman, terbukti pada ketiga app state.

## Fitur utama

- Login dengan guard route: belum login selalu diarahkan ke `/login`.
- Token (access + refresh) hanya disimpan di `flutter_secure_storage`.
- Dio interceptor: menyisipkan `Authorization: Bearer <access>` dan saat 401
  menukar refresh token **satu kali** lalu mengulang request. Bila refresh ikut
  mati, sesi dibersihkan dan pengguna dipaksa login ulang.
- FCM: izin runtime, `getToken` + `onTokenRefresh` dilaporkan ke `POST /devices`,
  langganan topik `pengumuman-kampus`.
- Notifikasi gabungan `notification` + `data`, klik membuka `/pengumuman/:id`
  pada state foreground, background, dan terminated.
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
| flutter_secure_storage | Penyimpanan access & refresh token |
| firebase_core + firebase_messaging | FCM: token, pesan, topik |
| flutter_local_notifications | Banner saat aplikasi foreground |

## Struktur

```text
lib/
├── main.dart                     # bootstrap Firebase + ProviderScope
├── routes.dart                   # konstanta path (dipakai router & FCM)
├── data/
│   ├── token_store.dart          # satu-satunya pintu token
│   ├── auth_repository.dart      # mock auth + refresh (titik ganti Firebase Auth)
│   ├── api_client.dart           # Dio + interceptor 401 -> refresh -> retry
│   ├── api_errors.dart           # DioException -> pesan ramah
│   ├── device_repository.dart    # POST/DELETE /devices
│   └── masking.dart              # maskSecret()
├── providers/
│   ├── auth_provider.dart        # AuthNotifier + apiClientProvider
│   ├── app_router.dart           # GoRouter + redirect guard
│   └── push_providers.dart       # PushController + PushState
├── messaging/
│   ├── firebase_bootstrap.dart   # init Firebase + background handler top-level
│   ├── payload.dart              # routeFromMessage / idFromMessage (fungsi murni)
│   └── push_service.dart         # permission, token, 3 handler, topik
└── pages/
    ├── login_page.dart
    ├── home_page.dart            # sesi + status notifikasi
    └── announcement_page.dart    # target deep link /pengumuman/:id
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

`google-services.json` dan `.secrets/` sudah di-`.gitignore` karena memuat
kredensial.

### 3. Build & jalankan

```bash
flutter pub get
flutter run
```

Login memakai auth mock: email apa pun yang mengandung `@` dan kata sandi
minimal 6 karakter.

### 4. Mengirim notifikasi uji

Cara paling andal (payload persis, bisa diulang) memakai FCM HTTP v1:

```bash
# Sekali saja: Firebase Console -> Project settings -> Service accounts
# -> Generate new private key, simpan sebagai .secrets/service-account.json

python tools/send_fcm.py --id 3          # kirim ke topik pengumuman-kampus
python tools/send_fcm.py --id 3 --token <FCM_TOKEN>   # ke satu perangkat
```

Alternatif lewat Firebase Console: Messaging → New campaign → **Firebase
Notification messages** → target **Topic** `pengumuman-kampus` → Additional
options: Android Notification Channel `pengumuman`, custom data
`route=/pengumuman/3` dan `id=3`.

> Catatan penting: target **User segment** tidak berfungsi pada project ini
> karena Google Analytics tidak diaktifkan, sehingga audiens kosong dan
> campaign terkirim ke 0 perangkat. Gunakan **Topic**.

## Hasil pengujian tiga app state

Diuji pada **Infinix X6882, Android 14 (API 34)**, aplikasi
`com.horoboy.campusnotif`, channel `pengumuman` (importance HIGH).

Payload yang dipakai untuk ketiga state:

```json
{
  "notification": { "title": "Jadwal kuliah berubah", "body": "Kelas Mobile pindah ke Ruang A2 jam 13.00" },
  "data": { "route": "/pengumuman/3", "id": "3" },
  "android": { "priority": "high", "notification": { "channel_id": "pengumuman" } }
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
flutter test      # All tests passed! (22 test)
```

| Berkas | Cakupan |
|---|---|
| `test/auth_test.dart` | guard route, login valid/invalid, sesi setengah jadi dibersihkan, refresh sukses/gagal |
| `test/api_client_test.dart` | 401 → refresh sekali → retry sukses (2 request); refresh mati → 1 request + sesi dibersihkan |
| `test/payload_test.dart` | `routeFromMessage`, `idFromMessage`, `sanitizeRoute`, `maskSecret` |

## Keamanan

- Token tidak pernah ditulis ke `SharedPreferences`, log, atau dirender utuh.
- Tidak ada `print`/`debugPrint` yang mencetak token (yang ada hanya id pesan).
- `google-services.json` dan `.secrets/` tidak masuk version control.
- Background handler berupa fungsi top-level `@pragma('vm:entry-point')` dan
  tidak menyentuh `BuildContext`, Riverpod, maupun router.

## Keterbatasan yang diketahui

- `AuthRepository` masih mock; titik ganti ke Firebase Auth ditandai di
  `lib/data/auth_repository.dart`.
- `kApiBaseUrl` masih domain contoh (`https://example-campus-api.test`), jadi
  `POST /devices` belum berhasil. Kontrak endpoint didokumentasikan di
  `lib/data/device_repository.dart`.
- `getToken`/`onTokenRefresh` ditandai deprecated oleh `firebase_messaging` 17
  (arahan ke `register`/`onRegistered`), tetapi tetap dipakai karena Console
  masih menargetkan FCM registration token. Lihat `docs/`.

## Dokumentasi

| Berkas | Isi |
|---|---|
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

