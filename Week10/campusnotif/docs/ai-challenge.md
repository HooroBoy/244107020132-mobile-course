# AI Challenge: audit draf PushService

Codelab Minggu 6 meminta draf `PushService` dibuat oleh AI, lalu **dibuktikan**
perilakunya oleh mahasiswa. Dokumen ini merekam prompt, output awal AI, apa yang
ditolak, apa yang diperbaiki, dan alasan teknisnya.

Draf mentah tersimpan utuh di [`ai-draft-raw.md`](ai-draft-raw.md).

## 1. Prompt yang dipakai (verbatim dari codelab)

```text
Aplikasi Flutter Campus Notification App.
Stack: firebase_messaging, flutter_local_notifications,
flutter_secure_storage, go_router, Riverpod.
Buatkan PushService dengan:
- requestPermission + getToken + onTokenRefresh (kirim ke POST /devices)
- onMessage (tampilkan local notification manual)
- onMessageOpenedApp + getInitialMessage (navigasi ke data.route)
- subscribe/unsubscribe topic pengumuman-kampus
- background handler top-level dengan @pragma('vm:entry-point')
Tandai bagian yang BERBEDA untuk Android 13+ vs iOS,
dan bagian yang tidak boleh mengakses BuildContext.
```

## 2. Ringkasan hasil audit

Draf dijalankan sebagai berkas Dart sungguhan di dalam project ini, lalu
dianalisis dengan `flutter analyze`:

```
16 issues found (9 error, 7 info)
```

**Draf tidak bisa dikompilasi.** Sembilan error itu bukan soal selera — itu API
yang tidak ada di versi paket yang dipakai project ini.

| # | Error | Lokasi | Sebab sebenarnya |
|---|---|---|---|
| 1 | `missing_required_argument: 'settings'` | `initialize(_initSettings)` | `flutter_local_notifications` 22.x mengubah `initialize()` menjadi **named parameter** `settings:` |
| 2 | `extra_positional_arguments: 0 expected, but 4 found` | `plugin.show(id, title, body, details, payload)` | 22.x mengubah `show()` menjadi **named parameter** (`id:`, `title:`, `body:`, `notificationDetails:`, `payload:`) |
| 3 | `undefined_named_parameter: 'encryptedSharedPreferences'` | `AndroidOptions(encryptedSharedPreferences: true)` | Opsi itu **tidak ada** di `flutter_secure_storage` 11.x |
| 4 | `non_type_in_catch_clause: 'FirebaseMessagingException'` (4×) | blok `on ... catch` | Kelas itu **tidak ada** di `firebase_messaging` 17.x |

Ketujuh temuan `info` juga relevan: `getToken`, `onTokenRefresh`, dan
`deleteToken` sudah deprecated di 17.x, dan draf memakai paket `http` yang tidak
ada di `pubspec.yaml` project.

## 3. Yang saya TERIMA dari draf AI

Bukan semua salah. Tiga hal memang bagus dan saya adopsi gagasannya:

| Yang diterima | Alasan |
|---|---|
| `@pragma('vm:entry-point')` pada handler top-level | Benar dan wajib; tanpa ini handler bisa di-strip compiler rilis |
| Pola `_routerReady` + `_pendingRoute` untuk menahan navigasi sampai router siap | Ini menutup race condition nyata: `getInitialMessage()` bisa selesai sebelum `GoRouter` terpasang. Saya terapkan pola yang sama (`addPostFrameCallback` di `main.dart` + `pendingDeepLink`) |
| Pemisahan `PushService` dari UI, navigasi lewat callback/router global, bukan `BuildContext` | Sesuai aturan codelab dan membuat kelas bisa diuji |

Satu detail kecil yang draf punya dan saya **tidak** pakai:
`onDidReceiveBackgroundNotificationResponse`. Tidak diadopsi karena pada
implementasi ini banner lokal hanya ditampilkan saat foreground — kalau aplikasi
di background, banner ditangani sistem, jadi handler itu tidak akan pernah
terpanggil. Menambahkannya hanya menambah kode mati.

## 4. Yang saya TOLAK, dan mengapa

### 4.1 Handler background menampilkan notifikasi sendiri → banner ganda

Draf melakukan ini:

```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  final local = FlutterLocalNotificationsPlugin();
  await _initLocalIsolate(local);
  await showCampusNotification(local, message);   // <-- ini masalahnya
}
```

Untuk pesan yang punya blok `notification`, Android **sudah** menampilkan banner
otomatis saat aplikasi background/terminated. Menampilkannya lagi lewat local
notification menghasilkan **dua notifikasi untuk satu pesan** — persis bug
"banner ganda" yang diperingatkan codelab.

Bukti dari pengujian nyata di proyek ini: setelah **satu** pesan dikirim,
`adb shell dumpsys notification | grep -c "NotificationRecord.*campusnotif"`
mengembalikan **1**. Kalau handler background ikut menampilkan, angkanya menjadi
2 untuk satu pesan yang sama.

Keputusan: handler background hanya mencatat id pesan. Tidak menyentuh UI.

### 4.2 Izin diminta dua kali

Draf memanggil `_messaging.requestPermission()` **dan**
`androidPlugin.requestNotificationsPermission()`. Di Android 13+ keduanya
memicu dialog izin yang sama. Pengguna bisa melihat dialog muncul, lalu
statusnya tidak konsisten karena hasil yang dikembalikan diambil dari panggilan
kedua.

Keputusan: satu jalur saja — `FirebaseMessaging.instance.requestPermission()`,
karena itu juga yang mengatur status di iOS. Channel tetap dibuat manual karena
itu kebutuhan Android 8+, bukan permintaan izin.

### 4.3 Rute deep link menyimpang dari spesifikasi

Draf memakai `/pengumuman/detail?id=3` (query parameter). Codelab menetapkan
`/pengumuman/:id` (path parameter), dan itu juga yang dipakai `GoRouter` di
project ini.

Selain itu `_sanitizeRoute` draf **menolak** rute tanpa garis miring di depan:

```dart
if (!route.startsWith('/') || route.startsWith('//')) return null;
```

Backend yang mengirim `pengumuman/3` (tanpa slash) akan membuat notifikasi
**tidak navigasi sama sekali** — diam-diam, tanpa error. Keputusan saya:
perbaiki menjadi `/pengumuman/3`, karena payload dari Console/backend sering
tidak konsisten. Ada test yang mengunci perilaku ini
(`test/payload_test.dart` → `routeFromMessage`).

### 4.4 Token dan payload berpotensi bocor ke log

Draf mencatat respons mentah:

```dart
dev.log('[push] POST /devices -> ${res.statusCode} ${res.body}');
```

`res.body` dari endpoint device bisa memuat token. Selain itu draf tidak pernah
menyamarkan token yang ditampilkan, padahal codelab meminta screenshot dengan
"token terpotong".

Keputusan: `maskSecret()` dipakai untuk semua tampilan token
(`abcd1234••••wxyz`), dan tidak ada `print`/`debugPrint` token di mana pun.
Diverifikasi dengan `grep -rn "print(|debugPrint|log(" lib/` → hanya satu
`debugPrint` yang mencetak **id pesan**, bukan token.

### 4.5 Versi paket tidak cocok

Draf menulis `firebase_core: ^4.1.0` dan `flutter_secure_storage: ^9.2.2`.
Project ini memakai `firebase_core 5.1.0` dan `flutter_secure_storage 11.2.0`.
Menyalin `pubspec` draf akan menurunkan versi dan memicu error resolusi.

Keputusan: versi mengikuti `pubspec.yaml` hasil `flutter pub add`, bukan draf.

## 5. Yang saya TAMBAHKAN (tidak ada di draf)

| Tambahan | Alasan |
|---|---|
| `routeFromMessage` / `idFromMessage` sebagai fungsi murni di `messaging/payload.dart` | Draf menaruh parsing di dalam kelas yang bergantung Firebase → tidak bisa diuji tanpa platform channel. Versi ini diuji 11 kasus di `test/payload_test.dart` (6 untuk `routeFromMessage`, 3 untuk `idFromMessage`, 2 untuk masking) |
| Status push yang bisa dilihat di UI (`PushState`) | Codelab menuntut bukti screenshot token terpotong + status izin; draf hanya menulis ke log |
| `bootstrapFirebase()` yang tidak mematikan aplikasi bila konfigurasi hilang | Draf memanggil `Firebase.initializeApp()` tanpa penanganan; bila `google-services.json` belum ada, aplikasi crash total sebelum UI tampil |
| `tools/send_fcm.py` (FCM HTTP v1) | Dua kegagalan nyata dari Firebase Console (target segment → 0 penerima, custom data tidak terkirim) membuat pengujian tidak bisa diandalkan lewat UI |

## 6. Pelajaran teknis

1. **Kode AI yang "terlihat benar" belum tentu kompilasi.** Draf ini sangat
   meyakinkan: penamaan rapi, komentar lengkap, penanda platform jelas. Tetap
   ada 9 error karena API berubah antar versi mayor. Yang membuktikan hanya
   `flutter analyze`, bukan membaca.
2. **Bug FCM yang paling mahal tidak terlihat dari kode.** Banner ganda,
   token basi, dan klik nyasar semuanya lolos review manual. Yang menemukan
   hanya pengujian di tiga app state dengan payload nyata.
3. **Verifikasi perilaku mengalahkan verifikasi kode.** Karena itu setiap
   klaim di README punya pasangan: test otomatis untuk logika, dan screenshot
   untuk perilaku perangkat.
