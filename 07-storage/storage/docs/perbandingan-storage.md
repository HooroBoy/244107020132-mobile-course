# Perbandingan Pilihan Local Storage

Evaluasi ini dibuat untuk dua kebutuhan berbeda: preferensi kecil dan koleksi 1.000+ catatan yang perlu disinkronkan.

| Kriteria | SharedPreferences | Hive | sqflite (SQLite) | Drift |
| --- | --- | --- | --- | --- |
| Kompleksitas query | Sangat terbatas; key-value | Filter dilakukan lewat kode/box | SQL lengkap: filter, sort, join, agregasi | Query SQL/Dart lengkap |
| Dukungan relasi | Tidak ada | Tidak native | Baik melalui foreign key/join | Baik dan type-safe |
| Reaktivitas (stream) | Tidak bawaan | `box.watch()` | Tidak bawaan; dipadukan dengan provider/invalidate | Bawaan melalui `watch()` |
| Type-safety | Hanya tipe primitif | Baik dengan adapter/generator | Mapping manual dari `Map` | Sangat baik melalui code generation |
| Ukuran boilerplate | Sangat kecil | Rendah–sedang | Sedang (skema, SQL, mapping) | Tinggi (tabel, generator, build runner) |
| Kemudahan testing | Mudah dengan nilai mock | Mudah dengan box sementara | Baik melalui dependency injection/fake repository | Baik dengan database in-memory |
| Cocok untuk preferensi? | **Ya, paling sesuai** | Bisa, tetapi berlebihan | Bisa, tetapi berlebihan | Bisa, tetapi berlebihan |
| Cocok untuk 1.000+ catatan? | **Tidak** | Cukup untuk objek sederhana | **Ya** | **Ya**, terutama bila perlu stream/query kompleks |

## Skema yang dipilih

```sql
CREATE TABLE notes(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  updated_at TEXT NOT NULL,
  dirty INTEGER NOT NULL DEFAULT 0
);
```

`updated_at` mendukung pengurutan serta aturan konflik last-write-wins. `dirty` membentuk antrean perubahan lokal yang belum diterima server.

## Keputusan

- **SharedPreferences** dipakai untuk `dark_mode` dan `last_opened_at` karena datanya kecil, primitif, dan dibaca berdasarkan key.
- **sqflite/SQLite** dipakai untuk catatan dan cache posts karena mendukung banyak baris, pengurutan, update parsial, transaksi atomik, dan migrasi skema.
- **Hive** tidak dipilih karena kebutuhan query/pengurutan dan potensi relasi akan lebih jelas dengan SQL.
- **Drift** belum dipilih karena fitur stream dan type-safety belum sebanding dengan tambahan code generation untuk ruang lingkup praktikum ini. Drift layak dipertimbangkan ketika query dan data berkembang.

Daftar catatan tidak disimpan sebagai satu JSON di SharedPreferences. Pendekatan tersebut mengharuskan seluruh koleksi dibaca, diurai, diubah, dan ditulis ulang untuk setiap perubahan serta tidak menyediakan query/transaksi yang andal