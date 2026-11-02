# Panduan & catatan pengujian FCM

Catatan ini merekam cara menguji notifikasi pada proyek ini, termasuk **dua
jebakan Firebase Console** yang membuat pengiriman gagal tanpa pesan error yang
jelas. Semuanya ditemukan lewat percobaan nyata pada perangkat
Infinix X6882 (Android 14 / API 34).

## Ringkasan hasil

| State | Handler | Hasil |
|---|---|---|
| Foreground | `onMessage` → banner lokal manual | Banner heads-up muncul, klik → `/pengumuman/9` |
| Background | `onMessageOpenedApp` | Banner sistem di shade, klik → `/pengumuman/5` |
| Terminated | `getInitialMessage` | Notifikasi masuk via background service, klik → app buka dari nol di `/pengumuman/3` |

Detail tabel bukti ada di `README.md`; tangkapan layar di `screenshots/`.
Hasil verifikasi ulang terbaru (termasuk temuan bug daftar yang basi dan catatan
mengapa state *terminated* sulit direproduksi di XOS) ada di bagian
[Hasil verifikasi di perangkat](#hasil-verifikasi-di-perangkat-infinix-x6882-android-14).

## Jebakan 1: target "User segment" mengirim ke 0 perangkat

Gejala di Firebase Console:

- Status campaign: **Completed**
- **Sends: 0**
- Tidak ada apa pun di perangkat, dan **tidak ada log FCM** di logcat

Penyebab: target dipilih **User segment** (`App = campusnotif`). Audiens user
segment dibangun dari **Google Analytics**. Project ini tidak mengaktifkan
Analytics (terlihat dari `google-services.json`: hanya ada
`appinvite_service`, tidak ada `analytics_service`), sehingga audiensnya
kosong.

Perbaikan: pilih tab **Topic** dan isi `pengumuman-kampus`.

Cara memastikan diagnosis ini: di daftar campaign, kolom **Target** hanya
menampilkan ikon Android tanpa nama topik. Campaign yang benar menargetkan
topik akan menampilkan nama topiknya.

## Jebakan 2: custom data tidak ikut terkirim

Gejala:

- Notifikasi muncul normal di background
- Klik membuka aplikasi, tetapi mendarat di beranda (`/`), bukan
  `/pengumuman/3`
- Kartu status di aplikasi menampilkan **Deep link terakhir: `/`**

Penyebab: blok **Additional options → Custom data** tidak terisi (atau tidak
tersimpan), sehingga `message.data` kosong. Handler
`routeFromMessage({})` mengembalikan `Routes.home` — perilaku yang memang
dirancang sebagai jaring pengaman, bukan bug.

Perbaikan: isi dua baris di tabel Custom data:

| Key | Value |
|---|---|
| `route` | `/pengumuman/3` |
| `id` | `3` |

Keduanya **string**, karena `data` payload FCM tidak mendukung tipe lain.

## Jalur yang lebih andal: FCM HTTP v1

Karena dua jebakan di atas berasal dari UI Console, pengujian akhir memakai
`tools/send_fcm.py` yang mengirim payload persis dan bisa diulang.

```bash
python tools/send_fcm.py --id 3
```

Di Windows tanpa paket Python `requests`/`google-auth`, pakai versi PowerShell
yang hanya bergantung pada `openssl.exe` dan `curl.exe` (parameter sama):

```powershell
powershell -ExecutionPolicy Bypass -File tools/send_fcm.ps1 -Id 3
```

Payload yang dibangun skrip:

```json
{
  "message": {
    "topic": "pengumuman-kampus",
    "notification": {
      "title": "Jadwal kuliah berubah",
      "body": "Kelas Mobile pindah ke Ruang A2 jam 13.00 (id 3)"
    },
    "data": { "route": "/pengumuman/3", "id": "3" },
    "android": {
      "priority": "high",
      "notification": { "channel_id": "pengumuman_v2" }
    }
  }
}
```

Respons sukses berisi nama pesan, bukan status 200 kosong:

```json
{ "name": "projects/campus-notify-dd809/messages/7485536739326318337" }
```

## Prosedur menguji ketiga state

```bash
ADB="$ANDROID_HOME/platform-tools/adb.exe"
```

**1. Foreground**

```bash
adb shell am start -n com.horoboy.campusnotif/.MainActivity
python tools/send_fcm.py --id 9
adb exec-out screencap -p > screenshots/02-foreground-banner.png
# ketuk banner dalam ~5 detik (heads-up hanya sebentar)
adb shell input tap 540 232
```

**2. Background**

```bash
adb shell input keyevent KEYCODE_HOME     # jangan swipe, cukup Home
adb shell pidof com.horoboy.campusnotif   # harus masih ada PID
python tools/send_fcm.py --id 5
adb shell input swipe 540 50 540 1600 300 # buka shade
adb shell input tap 540 1168              # ketuk notifikasi
```

**3. Terminated**

```bash
adb shell input keyevent KEYCODE_APP_SWITCH
adb shell input swipe 442 940 442 200 250 # swipe kartu ke atas
adb shell pidof com.horoboy.campusnotif   # harus kosong
python tools/send_fcm.py --id 3
```

Saat terminated, logcat menunjukkan handler background benar-benar jalan:

```
I FLTFireMsgService: FlutterFirebaseMessagingBackgroundService started!
```

## Tips agar pengujian tidak menipu diri sendiri

| Praktik | Alasan |
|---|---|
| Pakai `id` berbeda per state (9/5/3) | Membuktikan klik membawa payload notifikasi yang benar, bukan tertinggal di halaman sebelumnya |
| Bersihkan notifikasi lama sebelum tiap uji | Notifikasi grup membuat baris sulit dibedakan; salah ketuk = kesimpulan salah |
| Verifikasi `pidof` sebelum kirim (state terminated) | Memastikan aplikasi benar-benar mati, bukan sekadar di background |
| Ambil screenshot segera setelah banner muncul | Heads-up hanya tampil ±5 detik |
| Cek `dumpsys notification` bila ragu | Menampilkan isi `android.title`, channel, dan importance secara pasti |

## Memverifikasi fitur tampilan notifikasi (suara, daftar, badge, ikon)

Prosedur singkat untuk memeriksa empat fitur yang tidak bisa dibuktikan lewat
`flutter test`:

| Fitur | Langkah | Bukti yang diharapkan |
|---|---|---|
| Ikon aplikasi | Hapus aplikasi lama → `flutter run` → lihat layar utama | Ikon lonceng hijau dengan titik kuning, bukan logo Flutter |
| Suara kustom | Beranda → **Tampilkan notifikasi uji** | Nada kustom berbunyi sekali, bukan nada bawaan |
| Daftar notifikasi | Setelah notifikasi uji → ketuk lonceng | Satu entri "Jadwal kuliah berubah" dengan waktu relatif |
| Badge ikon | Tekan Home setelah notifikasi uji | Angka `1` pada ikon aplikasi (launcher yang mendukung) |
| Dibaca → hilang | Buka lonceng → ketuk entri | Entri hilang, lonceng tanpa angka, badge ikon hilang |
| Terkirim dari server | `python tools/send_fcm.py --id 3` saat aplikasi terbuka | Banner + entri baru di daftar + suara kustom |

Yang perlu diwaspadai:

- Setelan channel Android **tidak bisa diubah**. Bila perangkat pernah
  menjalankan versi dengan channel `pengumuman`, suara kustom hanya berlaku pada
  channel baru `pengumuman_v2`. Pastikan payload juga memakai `pengumuman_v2`.
- Badge angka bergantung launcher. Uji di Samsung/MIUI/Oppo/Vivo; Pixel Launcher
  hanya menampilkan titik.
- Notifikasi yang diketuk dari panel sistem sengaja langsung dihapus dari daftar
  (dianggap sudah dibaca).

## Hasil verifikasi di perangkat (Infinix X6882, Android 14)

Dijalankan pada APK `--debug` yang dipasang lewat `adb install -r`, dengan
pengiriman nyata memakai service account project `campus-notify-dd809`.

| Fitur | Bukti yang dikumpulkan | Hasil |
|---|---|---|
| Login/sesi | Beranda menampilkan email sesi + FCM token | Berjalan (memakai sesi lama; provider Email/Password belum aktif di project — lihat catatan di bawah) |
| Banner foreground | `dumpsys notification`: `NotificationRecord(... channel=pengumuman_v2 importance=4)` | Lolos |
| Suara kustom | `dumpsys notification`: channel `pengumuman_v2` dengan `mSound=campus_notif`; APK memuat `res/raw/campus_notif.wav` (RIFF/WAVE, 44,1 kHz stereo, 0,32 s) | Konfigurasi lolos; bunyi terdengar hanya bila mode dering **Ring** |
| Daftar notifikasi | Halaman `/notifikasi` menampilkan 3 entri dengan waktu relatif dan rute (`/pengumuman/11`, `/12`, `/13`) | Lolos |
| Dibaca → hilang | Mengetuk entri membuka `/pengumuman/11`, entri hilang, `campus_notif.inbox` menjadi `[]` setelah "tandai semua dibaca" | Lolos |
| Badge ikon | Ikon aplikasi di drawer menampilkan **titik** merah (bukan angka) | Sesuai batasan launcher XOS |
| Badge lonceng | Angka pada lonceng = 1 → 2 → 3 mengikuti isi penyimpanan | Lolos |
| Background | `KEYCODE_HOME` lalu kirim topik: banner sistem muncul, entri tertulis ke penyimpanan oleh handler background | Lolos |
| Terminated | Tidak dapat direproduksi: `am kill`, `am kill-all`, dan tutup dari recents tidak menghentikan proses di XOS (proses tetap hidup, `pidof` tidak kosong) | Tidak teruji di perangkat ini |

**Catatan Authentication.** Pada project `campus-notify-dd809`, Identity Platform
belum pernah diinisialisasi: `accounts:signUp` dan Admin API
`projects/{id}/config` sama-sama menjawab `CONFIGURATION_NOT_FOUND`, dan
`initializeAuth` juga 404. Artinya provider Email/Password tidak bisa diaktifkan
lewat API — harus sekali lewat Firebase Console (**Authentication → Get started →
Email/Password**). Karena itu verifikasi login memakai sesi yang sudah tersimpan
di perangkat. Setelah provider aktif, buat akun uji lewat Console atau
`accounts:signUp`, lalu tekan **Keluar** di beranda agar sesi lama (`mock-acc…`)
tidak terpakai lagi.

Bukti pendukung yang dipakai (tanpa screenshot):

```bash
# channel + suara + importance
adb shell dumpsys notification --noredact | grep -A1 'NotificationRecord.*campusnotif'

# isi kotak masuk yang sebenarnya (sumber kebenaran)
adb shell run-as com.horoboy.campusnotif \
  cat files/datastore/FlutterSharedPreferences.preferences_pb

# teks UI tanpa screenshot
adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml .
```

### Bug yang ditemukan dan diperbaiki saat verifikasi

Notifikasi yang masuk ketika aplikasi di background ditulis oleh isolate lain,
sehingga lonceng dan badge tetap menunjukkan angka lama sampai aplikasi dibuka
ulang (terbukti: penyimpanan berisi 2 entri, lonceng menampilkan 1). Perbaikan:
`reload()` dipanggil pada `AppLifecycleListener(onResume:)` dan pada `initState`
halaman `/notifikasi`, plus satu regression test.

### Catatan pengujian yang menipu

- `adb shell am force-stop <pkg>` menaruh aplikasi di *stopped state*; Android
  **menahan** pengiriman FCM sampai aplikasi dibuka manual. Percobaan pertama
  pada sesi ini terlihat "notifikasi tidak masuk" padahal penyebabnya ini.
- `am kill` hanya menghentikan proses berstatus *cached*. Pada XOS proses tetap
  hidup walau sudah keluar dari recents.
- Suara tidak akan terdengar saat mode dering **Vibrate/Silent**: AudioService
  menandai `STREAM_NOTIFICATION` sebagai `Muted: true` walau volume dinaikkan.
  Setelah slider Notifikasi digeser, sistem tetap membuat pemutar
  `USAGE_NOTIFICATION` untuk setiap notifikasi — tanda jalur suara benar.

## Catatan lingkungan

- Android 14 memblokir sebagian broadcast dan membekukan proses di background.
  Proyek ini teruji tanpa perlu mematikan optimasi baterai; bila notifikasi
  tidak masuk di perangkat lain, cek `adb shell am get-standby-bucket` dan
  pertimbangkan whitelist.
- Pada Gradle di Windows, build bisa gagal karena `java.io.tmpdir` menunjuk
  direktori sementara sesi sebelumnya. Jalankan `gradlew.bat --stop` dari
  `android/` lalu build ulang.
