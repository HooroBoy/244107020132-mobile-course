# Offline Notes

Aplikasi Flutter untuk mempraktikkan **local storage** dan pola **offline-first**. Catatan tetap dapat dibaca serta diubah tanpa jaringan, lalu ditandai untuk sinkronisasi. Preferensi tema disimpan terpisah dari data terstruktur.

## Fitur utama

- Tema terang/gelap dan waktu terakhir dibuka melalui SharedPreferences.
- CRUD catatan persisten melalui SQLite (`sqflite`).
- Empat state UI: loading, error, empty, dan success.
- `dirty` badge untuk catatan yang belum tersinkron.
- Sinkronisasi server simulasi dengan penolakan deterministik saat offline.
- Cache-first posts dari JSONPlaceholder: cache lokal tampil sebelum refresh jaringan.
- Halaman detail `/note/:id` dengan GoRouter dan pembacaan langsung dari repository.
- Tema Material 3, konfirmasi hapus, validasi form, dan feedback snackbar.
- Test model, provider, antrean sync, kondisi offline, serta aturan konflik dengan fake repository.

## Stack teknologi

| Teknologi | Kegunaan |
|---|---|
| Flutter / Dart | UI aplikasi mobile |
| Riverpod | State management, dependency injection, dan `AsyncValue` |
| SharedPreferences | Preferensi key-value |
| sqflite + path | SQLite lokal dan path database lintas platform |
| Dio | HTTP client untuk posts |
| GoRouter | Navigasi dan halaman detail berbasis ID |

## Arsitektur

```text
UI (pages/widgets)
  └─ watch/call → Riverpod providers/actions
                    └─ call → repositories
                                ├─ SharedPreferences
                                ├─ SQLite
                                └─ REST API (Dio)
```

UI tidak mengimpor atau memanggil SQLite/SharedPreferences secara langsung. Struktur utama:

```text
lib/
├── data/
│   ├── local/                 # model Note dan database
│   ├── remote/                # model Post
│   ├── repositories/          # akses tunggal ke data
│   ├── prefs.dart
│   └── sync.dart
├── pages/                     # halaman aplikasi
├── providers/                 # state dan actions Riverpod
├── widgets/                   # komponen UI reusable
└── main.dart                  # tema dan router
```

## Menjalankan aplikasi

> `sqflite` pada konfigurasi praktikum ditujukan untuk Android/iOS. Gunakan emulator atau perangkat Android, bukan Chrome.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Setelah pertama kali menambahkan plugin, lakukan full restart aplikasi (bukan hanya hot reload).

## Alur uji singkat

1. Tambah catatan; badge dirty bertambah dan label **Belum tersinkron** tampil.
2. Buka **Pengaturan**, aktifkan **Paksa mode offline**, lalu tekan sync; antrean tetap utuh.
3. Nonaktifkan mode offline dan tekan sync; setelah simulasi satu detik badge menghilang.
4. Saat online, buka **Posts** sekali untuk mengisi cache.
5. Aktifkan mode offline dan buka Posts lagi; data berasal dari SQLite lokal.
6. Ubah tema, tutup paksa aplikasi, lalu buka kembali untuk memeriksa persistensi.

Skenario lengkap dan daftar screenshot ada di [`docs/uji-offline.md`](docs/uji-offline.md).

## Strategi offline-first

- **Tulisan pengguna:** setiap create/update langsung masuk SQLite dengan `dirty = 1`. Sinkronisasi hanya membersihkan flag setelah upload simulasi berhasil.
- **Data bacaan:** posts memakai cache-first. Cache dibaca terlebih dahulu; saat online, data segar diambil dan disimpan dalam transaksi.
- **Konflik:** last-write-wins berdasarkan `updated_at`. Versi dengan waktu terbaru dipilih oleh fungsi murni `resolveConflict()`.

### Batasan sinkronisasi

Server tulis masih disimulasikan. `markAllSynced()` dapat salah membersihkan perubahan yang terjadi selama upload. Sistem produksi perlu update kondisional berdasarkan `id + updated_at` atau tabel outbox. Delete produksi juga membutuhkan tombstone agar penghapusan dapat diteruskan ke server.

## Testing

Test memakai `ProviderContainer` dan `FakeNoteRepository`; fungsi pembuka database palsu melempar `UnimplementedError` agar test tidak diam-diam menyentuh plugin/database nyata.

```bash
flutter test
```

## Dokumentasi

- [Perbandingan storage dan keputusan](docs/perbandingan-storage.md)
- [AI challenge dan verifikasi](docs/ai-challenge.md)
- [Jawaban pertanyaan praktikum](docs/jawaban-praktikum.md)
- [Skenario uji offline/manual](docs/uji-offline.md)

## Hasil yang dituju

Implementasi mencakup seluruh Praktikum 1–5 dan refactoring challenge. Analisis/test otomatis dicatat melalui keluaran terminal. Bukti screenshot mode pesawat harus diambil pada perangkat Android yang benar dan tidak disertakan secara palsu oleh proses otomatis.