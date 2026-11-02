# Dokumentasi Campus Notify

Indeks seluruh dokumentasi proyek. Mulai dari sini, lalu pilih sesuai kebutuhan.

## Peta dokumen

| Berkas | Untuk siapa | Isi |
|---|---|---|
| [`../README.md`](../README.md) | Dosen / penilai / pembaca pertama | Ringkasan proyek, fitur, stack, cara menjalankan, bukti pengujian tiga app state |
| [`arsitektur.md`](arsitektur.md) | Developer yang baru bergabung | Peta lapisan, graf dependency provider, alur login / refresh 401 / FCM / deep link, keputusan desain |
| [`referensi-kode.md`](referensi-kode.md) | Developer yang mengubah kode | Kontrak setiap berkas di `lib/`: kelas, fungsi, konstanta, invariant, dan test yang mengunci perilakunya |
| [`panduan-pengembangan.md`](panduan-pengembangan.md) | Developer | Prasyarat, perintah harian, konfigurasi Firebase, konvensi kode, resep perubahan, cara menulis test, troubleshooting |
| [`panduan-pengguna.md`](panduan-pengguna.md) | Pengguna aplikasi / penguji manual | Alur layar login → beranda, arti setiap status di kartu notifikasi, lonceng & daftar notifikasi, suara, perilaku notifikasi di tiga app state |
| [`uji-fcm.md`](uji-fcm.md) | Penguji | Prosedur uji tiga app state via ADB, verifikasi suara/daftar/badge/ikon, dan dua jebakan Firebase Console |
| [`refleksi.md`](refleksi.md) | Dosen / mahasiswa | Jawaban empat pertanyaan refleksi codelab (secure storage, `onTokenRefresh`, topik vs token) |
| [`ai-challenge.md`](ai-challenge.md) | Dosen / mahasiswa | Audit draf `PushService` buatan AI: 9 error kompilasi, bagian yang diterima, ditolak, dan ditambahkan |
| [`ai-draft-raw.md`](ai-draft-raw.md) | Dosen / mahasiswa | Draf AI mentah, disimpan apa adanya sebagai bukti audit |

## Jalur baca yang disarankan

- **Ingin menjalankan aplikasi saja** → [`../README.md`](../README.md) bagian *Cara menjalankan*, lalu [`panduan-pengguna.md`](panduan-pengguna.md).
- **Ingin memahami cara kerjanya** → [`arsitektur.md`](arsitektur.md) → [`referensi-kode.md`](referensi-kode.md).
- **Ingin mengubah / melanjutkan kode** → [`panduan-pengembangan.md`](panduan-pengembangan.md) → resep perubahan di bagian akhir dokumen itu.
- **Ingin menguji notifikasi di perangkat** → [`uji-fcm.md`](uji-fcm.md).

## Ringkasan proyek dalam satu paragraf

Campus Notify adalah aplikasi Flutter yang menyatukan alur lengkap: login lewat
Firebase Authentication, token yang disimpan aman, klien HTTP yang otomatis
menukar refresh token saat menerima 401, notifikasi FCM yang membawa deep link
ke `/pengumuman/:id` pada state foreground, background, dan terminated, kotak
masuk notifikasi yang mengosongkan entri begitu dibaca, badge angka pada ikon
aplikasi, serta suara notifikasi kustom dari berkas aset. Seluruh kode berada di
`lib/` dengan pembagian `data/` (sumber data), `providers/` (state & dependency
injection), `messaging/` (FCM), dan `pages/` (UI).

## Status verifikasi

Diperiksa ulang pada 2 November 2026 dengan Flutter 3.47.7 / Dart 3.13.5:

```bash
flutter analyze            # No issues found! (ran in 3.5s)
flutter test               # All tests passed! (46 test)
flutter build apk --debug  # Built build/app/outputs/flutter-apk/app-debug.apk
```

Angka 46 terdiri dari 11 test di `test/payload_test.dart`, 3 di
`test/api_client_test.dart`, 8 di `test/auth_test.dart`, dan 24 di
`test/notification_test.dart` (termasuk widget test alur "dibaca → hilang").

Build APK diverifikasi memuat `res/raw/campus_notif.wav`, ikon adaptive
`mipmap-*/ic_launcher.*`, dan aset suara pada `flutter_assets`. Perilaku runtime
di perangkat (suara, badge launcher) **belum** diuji ulang untuk fitur baru ini.

## Konvensi dokumen

- Bahasa Indonesia, istilah teknis dibiarkan dalam bentuk aslinya
  (*refresh token*, *deep link*, *foreground*).
- Setiap klaim perilaku di dokumen ini punya pasangan bukti: nama test di
  `test/`, atau nama berkas di `screenshots/`.
- Bila dokumen dan kode berbeda, **kode adalah kebenaran** — dokumen ini
  diperbarui mengikuti kode, bukan sebaliknya.
