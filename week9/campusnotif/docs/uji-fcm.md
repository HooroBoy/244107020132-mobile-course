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
      "notification": { "channel_id": "pengumuman" }
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

## Catatan lingkungan

- Android 14 memblokir sebagian broadcast dan membekukan proses di background.
  Proyek ini teruji tanpa perlu mematikan optimasi baterai; bila notifikasi
  tidak masuk di perangkat lain, cek `adb shell am get-standby-bucket` dan
  pertimbangkan whitelist.
- Pada Gradle di Windows, build bisa gagal karena `java.io.tmpdir` menunjuk
  direktori sementara sesi sebelumnya. Jalankan `gradlew.bat --stop` dari
  `android/` lalu build ulang.
