# Jawaban Pertanyaan Praktikum

## Praktikum 1 — SharedPreferences

1. **Mengapa `SharedPreferences.getInstance()` tidak dipanggil di `build()`?**  
   `build()` harus cepat dan dapat dipanggil berkali-kali. Operasi async di dalamnya dapat memicu pembacaan berulang, kedipan UI, dan kode yang sulit diuji. Repository memusatkan plugin, sedangkan provider menyimpan serta mengekspos state.

2. **Alur perubahan tema.**  
   Switch memanggil `DarkModeNotifier.setDarkMode()`. Notifier lebih dulu memasang `AsyncData` baru agar UI responsif. `OfflineNotesApp` yang mengawasi provider membangun ulang `MaterialApp.router` dengan `ThemeMode` baru, sementara repository menulis nilai ke SharedPreferences. Ketika aplikasi dibuka lagi, `build()` notifier membaca nilai tersebut.

3. **Kelebihan dan risiko optimistic update.**  
   Kelebihannya adalah perubahan terlihat langsung tanpa loading. Risikonya, UI sempat menunjukkan nilai yang ternyata gagal disimpan. Karena itu notifier menyimpan state sebelumnya dan melakukan rollback saat repository melempar error.

## Praktikum 2 — SQLite

1. **Mengapa `dirty` berupa INTEGER?**  
   SQLite tidak memiliki tipe boolean storage class khusus. Nilai boolean dipetakan menjadi `1` dan `0`.

2. **Fungsi parameter `openDb`.**  
   Parameter ini adalah dependency injection. Test dapat menyuntikkan pembuka database palsu atau fungsi yang langsung gagal sehingga tidak pernah menyentuh plugin SQLite.

3. **Mengapa memakai `whereArgs`?**  
   Placeholder dan `whereArgs` memastikan nilai di-bind sebagai parameter, bukan digabung ke SQL. Ini menghindari SQL injection dan masalah escaping.

4. **Apa akibat menambah kolom di `onCreate` tanpa menaikkan versi?**  
   Database lama tidak menjalankan `onCreate` lagi sehingga kolom tidak pernah dibuat. Query terhadap kolom tersebut akan menghasilkan `no such column`. Solusinya menaikkan `version` dan menulis `onUpgrade`.

## Praktikum 3 — Riverpod dan CRUD

1. **Mengapa `notesProvider` dan `dirtyCountProvider` sama-sama di-invalidate?**  
   Keduanya melihat tabel yang sama dari sudut berbeda. Hanya me-refresh daftar membuat badge basi; hanya me-refresh hitungan membuat isi daftar basi.

2. **Cara memicu error state.**  
   Override `noteRepositoryProvider` dengan fake yang melempar exception dari `fetchNotes()`. Ini lebih aman daripada sengaja merusak tabel produksi dan dapat dilakukan deterministik di test.

3. **Mengapa CRUD tetap berfungsi dalam mode pesawat?**  
   Semua operasi catatan membaca dan menulis SQLite lokal. Jaringan hanya terlibat ketika sinkronisasi atau mengambil posts.

## Praktikum 4 — Offline-first

1. **Cache-first vs network-first.**  
   Cache-first menampilkan data lokal lalu memperbarui dari jaringan; cocok untuk artikel dan katalog. Network-first mencoba server lebih dahulu dan memakai cache sebagai fallback; cocok untuk saldo, stok, atau harga real-time.

2. **Risiko `markAllSynced()`.**  
   Catatan yang diedit saat upload berlangsung dapat ikut ditandai bersih walaupun versi barunya belum dikirim. Perbaikannya adalah update dengan syarat `id` dan `updated_at` sama dengan versi yang dikirim, atau memakai outbox per operasi.

3. **Mengapa masih membutuhkan `forceOffline`?**  
   Mode ini membuat demo dan test deterministik tanpa tergantung Wi-Fi, pengaturan sistem, atau kondisi perangkat.

4. **Mengapa cache ditulis dalam transaksi?**  
   Penghapusan cache lama dan penyisipan cache baru harus atomik. Jika salah satu insert gagal, transaksi di-rollback sehingga cache lama tidak berubah menjadi data setengah jadi.

## Praktikum 5 — Testing

1. **Mengapa `ProviderContainer` + override, bukan database asli?**  
   Fake repository membuat test cepat, deterministik, berjalan tanpa emulator/plugin, dan memusatkan pengujian pada alur provider. Database asli lebih tepat diuji terpisah sebagai integration test.

2. **Manfaat parameter `latency`.**  
   Aplikasi dapat tetap menyimulasikan upload satu detik, sementara unit test memakai `Duration.zero` agar cepat dan stabil.

3. **Test tambahan yang penting.**  
   Uji bahwa PostsNotifier mengembalikan cache saat offline dan tidak melakukan request jaringan. Ini melindungi janji utama pola cache-first dari regresi.

## Refleksi

1. **Mengapa catatan bukan SharedPreferences?**  
   Satu perubahan akan membaca, decode, mengubah, encode, dan menulis seluruh JSON. Query, transaksi, migrasi, serta sinkronisasi per baris juga menjadi rapuh.

2. **Kapan cache-first cukup?**  
   Saat data lama masih berguna dan kecepatan tampil lebih penting, seperti artikel. Network-first diperlukan ketika keputusan pengguna bergantung pada nilai server terkini.

3. **Bagaimana dirty flag menjadi antrean?**  
   Mutasi lokal menandai baris `dirty = 1` tanpa menunggu server. Sync memproses baris tersebut dan membersihkan flag setelah sukses. Outbox diperlukan ketika operasi harus mempertahankan urutan, delete harus dikirim sebagai tombstone, retry berbeda per operasi, atau audit dibutuhkan.

4. **Bagian rekomendasi AI yang ditolak/dikoreksi.**  
   Klaim bahwa sqflite otomatis reaktif ditolak: sqflite sendiri tidak menyediakan stream perubahan. Reaktivitas di aplikasi ini berasal dari Riverpod dan invalidation. Penyimpanan daftar catatan di SharedPreferences juga ditolak walaupun mungkin tampak lebih sederhana untuk demo kecil