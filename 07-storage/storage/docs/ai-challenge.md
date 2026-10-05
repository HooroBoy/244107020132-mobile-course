# AI Prompt Challenge dan Verifikasi

## Prompt yang digunakan

> Aplikasi Flutter Offline Notes: CRUD catatan + preferensi tema. Bandingkan SharedPreferences, Hive, sqflite (SQLite), dan Drift untuk dua kebutuhan ini. Kriteria: kompleksitas query, kebutuhan relasi, reaktivitas (stream), type-safety, ukuran boilerplate, dan kemudahan testing. Beri rekomendasi final: mana untuk preferensi, mana untuk catatan, beserta alasannya dalam satu tabel. Tunjukkan skema tabel/kotak untuk 1.000+ catatan. Jelaskan trade-off setiap pilihan.

## Ringkasan output awal AI

AI membedakan storage berdasarkan bentuk data, bukan memakai satu teknologi untuk semuanya:

- SharedPreferences unggul untuk key-value kecil, tetapi tidak layak untuk koleksi catatan.
- Hive sederhana dan cepat untuk objek lokal, tetapi query relasionalnya terbatas.
- sqflite memberi kontrol SQL dan transaksi dengan mapping manual.
- Drift memberi query reaktif dan type-safe, tetapi membutuhkan code generation dan boilerplate lebih besar.

Rekomendasi awalnya adalah SharedPreferences untuk preferensi dan SQLite untuk catatan. Rekomendasi tersebut diterima setelah diverifikasi terhadap dokumentasi paket dan kebutuhan aplikasi.

## Checklist verifikasi

| Pemeriksaan | Temuan | Keputusan |
|---|---|---|
| Apakah daftar catatan ditempatkan di SharedPreferences? | Tidak. Hanya tema dan waktu buka yang berupa key-value. | Diterima |
| Apakah skema mendukung antrean sinkronisasi? | Ya, tabel `notes` memiliki `dirty` dan `updated_at`. | Diterima |
| Apakah klaim reaktif didukung API nyata? | Hive memiliki `box.watch()` dan Drift memiliki query `watch()`. sqflite tidak otomatis reaktif; aplikasi memakai Riverpod + invalidation. | Dikoreksi/diperjelas |
| Apakah estimasi boilerplate masuk akal? | sqflite membutuhkan mapping dan migrasi manual. Drift menambah deklarasi tabel serta code generation. | Diterima |
| Apakah pilihan dapat diuji? | Repository menerima fungsi `openDb`, provider dapat di-override dengan fake repository. | Diterima |

## Keputusan final

Kombinasi **SharedPreferences + sqflite** dipilih. Keputusan bukan karena keduanya selalu terbaik, melainkan karena sesuai dengan dua bentuk data aplikasi saat ini dan tetap mudah dijelaskan, dimigrasikan, serta diuji. Detail tabel akhir ada di [perbandingan-storage.md](perbandingan-storage.md).

## Batasan yang ditemukan

Implementasi sinkronisasi masih berupa server simulasi. `markAllSynced()` dapat mengalami race condition bila catatan diubah ketika upload berlangsung. Sistem produksi seharusnya menandai bersih berdasarkan pasangan `id + updated_at` yang benar-benar dikirim atau menggunakan tabel outbox