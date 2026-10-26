# Refleksi

Jawaban atas empat pertanyaan refleksi pada codelab Minggu 6.

## 1. Mengapa refresh token tidak boleh disimpan di SharedPreferences? Apa risikonya bila bocor?

`SharedPreferences` menyimpan data sebagai berkas XML biasa di direktori
privat aplikasi (`/data/data/<package>/shared_prefs/`), **tanpa enkripsi**.
Siapa pun yang bisa membaca direktori itu mendapat isinya apa adanya.

Tiga jalur kebocoran yang realistis:

| Jalur | Penjelasan |
|---|---|
| Perangkat di-root | Aplikasi apa pun dengan akses root bisa membaca XML tersebut langsung |
| Backup otomatis | `android:allowBackup` default `true`; XML ikut tersalin ke cloud/PC saat backup, lalu bisa dibaca di sana |
| ADB debug / malware dengan akses storage | Pada perangkat debug, `adb shell run-as` bisa membaca isi sandbox aplikasi |

`flutter_secure_storage` menutup celah itu dengan menyimpan nilai di
**Android Keystore** (kunci AES dipegang hardware-backed keystore, tidak bisa
diekstrak) dan **iOS Keychain**.

Risiko spesifik bila **refresh token** yang bocor jauh lebih besar daripada
access token bocor:

- Access token berumur pendek (±15 menit) — bocornya hanya membuka jendela
  singkat.
- Refresh token berumur panjang (hari sampai bulan) dan **tidak bisa dicabut
  tanpa menyentuh server**. Penyerang bisa terus menukarnya menjadi access
  token baru, bahkan setelah pengguna mengganti kata sandi, kecuali server
  menerapkan rotasi refresh token + deteksi pemakaian ulang.
- Pada aplikasi kampus, token itu membuka data pribadi: nilai, tagihan,
  jadwal, dan identitas mahasiswa.

Karena itu aturan proyek ini: **refresh token hanya hidup di
`flutter_secure_storage`, dan seluruh aksesnya lewat satu kelas
(`TokenStore`)** sehingga tidak ada kode lain yang bisa "kreatif" menyimpannya
di tempat lain.

## 2. Apa yang rusak bila `onTokenRefresh` diabaikan selama satu semester perkuliahan?

FCM registration token **berubah** tanpa memberi tahu aplikasi. Pemicunya
antara lain: instalasi ulang, clear data, restore ke perangkat baru, dan rotasi
keamanan dari sisi Google.

Bila `onTokenRefresh` tidak dipasang:

1. Backend tetap menyimpan token lama. Setiap pengiriman ke token itu dijawab
   FCM dengan `UNREGISTERED` / `NOT_FOUND`.
2. Pengguna berhenti menerima notifikasi **tanpa pesan error apa pun di
   aplikasi** — dari sisi mahasiswa, aplikasi tampak normal, hanya "tidak pernah
   ada pengumuman".
3. Karena tidak ada error, tidak ada yang melapor. Kegagalan ini senyap dan
   baru ketahuan saat ada pengumuman penting (mis. perubahan jadwal ujian).
4. Beban backend menumpuk: daftar token penuh entri mati, dan pengiriman
   broadcast jadi sia-sia untuk sebagian besar penerima.
5. Bila token lama sudah dipakai ulang oleh instalasi lain (kasus langka tapi
   mungkin), notifikasi personal bisa salah sasaran.

Dalam satu semester, kerusakannya bersifat kumulatif: setiap instalasi ulang
dan setiap reset HP menambah satu pengguna yang "hilang" dari daftar penerima,
dan tidak ada mekanisme yang memulihkannya karena satu-satunya pemicu
pembaruan token adalah listener itu.

Perbaikan yang diterapkan di proyek ini: `initFcmToken()` mengirim token saat
ini **dan** berlangganan `onTokenRefresh` yang memanggil callback pengiriman ke
backend yang sama — bukan sekadar mencetak ke log.

## 3. Kapan memakai topik dan kapan memakai token perangkat? Beri contoh pesan kampus untuk masing-masing.

Aturan praktis: **topik untuk siaran (satu pesan, banyak penerima yang tidak
diketahui identitasnya), token untuk pesan personal (satu penerima spesifik)**.

| Aspek | Topik | Token perangkat |
|---|---|---|
| Penerima | Siapa pun yang subscribe, tidak perlu didata backend | Satu perangkat milik satu pengguna |
| Beban backend | Kirim 1 request, FCM yang menyebar | Harus menyimpan token per user dan mengirim per token |
| Risiko salah sasaran | Rendah untuk broadcast, **tinggi untuk data pribadi** | Terkontrol, karena terikat ke user |
| Kapan dipakai | Pengumuman umum, perubahan jadwal, info UKM | Nilai, tagihan, verifikasi, pesan yang menyebut nama |

**Contoh pesan kampus dengan topik** (`pengumuman-kampus`):

> "Jadwal kuliah berubah — Kelas Mobile pindah ke Ruang A2 jam 13.00."

Semua mahasiswa perlu tahu, isinya sama untuk semua, dan tidak ada data
pribadi. Bisa juga dipecah per angkatan (`angkatan-2024`) atau per UKM
(`ukm-robotika`) — topik tidak harus satu untuk seluruh kampus.

**Contoh pesan kampus dengan token perangkat:**

> "Nilai mata kuliah Pemrograman Mobile sudah keluar. Buka SIAKAD untuk
> melihat detail." — dikirim hanya ke token milik mahasiswa yang
> bersangkutan.

Isinya menyangkut satu orang. Kalau dikirim lewat topik, seluruh mahasiswa
menerima notifikasi "nilai sudah keluar" yang membingungkan, dan bila isinya
lebih detail (mis. menyebut nama atau NIM), itu kebocoran data pribadi.

Konsekuensi desain: pesan personal menuntut backend punya tabel
`user_id -> fcm_token`, dan token harus **dilepas saat logout**
(`DELETE /devices`) agar perangkat yang sudah keluar tidak lagi menerima pesan
pribadi pemilik sebelumnya.
