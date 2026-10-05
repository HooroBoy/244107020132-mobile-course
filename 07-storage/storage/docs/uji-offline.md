# Skenario Uji Offline-First

Dokumen ini memisahkan verifikasi otomatis dari uji manual perangkat. Kolom hasil aktual manual harus diisi setelah aplikasi dijalankan pada Android, karena screenshot dan kondisi mode pesawat tidak boleh direkayasa.

## Praktikum 3 — CRUD lokal

| No. | Skenario | Langkah | Hasil yang diharapkan | Hasil aktual | Status |
|---|---|---|---|---|---|
| 1 | Empty state | Buka aplikasi pada instalasi baru | Pesan “Belum ada catatan” tampil | Menunggu uji perangkat | Belum diuji |
| 2 | Create | Tekan **Catatan**, isi judul, simpan | Catatan paling atas, label belum tersinkron, badge bertambah | Menunggu uji perangkat | Belum diuji |
| 3 | Validasi | Simpan dengan judul kosong | “Judul wajib diisi”, dialog tetap terbuka | Menunggu uji perangkat | Belum diuji |
| 4 | Update | Buka detail, tekan Ubah, lalu simpan | Isi berubah dan waktu diperbarui | Menunggu uji perangkat | Belum diuji |
| 5 | Delete | Tekan ikon hapus dan konfirmasi | Catatan hilang | Menunggu uji perangkat | Belum diuji |
| 6 | Persistensi | Tutup paksa lalu buka aplikasi | Catatan tetap tersedia | Menunggu uji perangkat | Belum diuji |
| 7 | Mode pesawat | Aktifkan mode pesawat, ulangi CRUD | CRUD tetap berjalan tanpa jaringan | Menunggu uji perangkat | Belum diuji |

## Praktikum 4 — cache dan sinkronisasi

| No. | Skenario | Langkah | Hasil yang diharapkan | Hasil aktual | Status |
|---|---|---|---|---|---|
| 1 | Isi cache | Online, buka Posts | 100 posts tampil dan masuk `cached_posts` | Menunggu uji perangkat | Belum diuji |
| 2 | Cache offline | Setelah cache terisi, aktifkan mode offline dan buka Posts | Posts tetap tampil dari cache | Menunggu uji perangkat | Belum diuji |
| 3 | Antrean dirty | Offline, tambah tiga catatan | Badge menunjukkan 3 | Menunggu uji perangkat | Belum diuji |
| 4 | Sync ditolak | Aktifkan **Paksa mode offline**, tekan sync | Pesan sinkronisasi ditunda; badge tetap 3 | Menunggu uji perangkat | Belum diuji |
| 5 | Sync berhasil | Nonaktifkan offline, tekan sync | Setelah ±1 detik badge hilang dan ikon menjadi tersinkron | Menunggu uji perangkat | Belum diuji |
| 6 | Refresh background | Online, buka Posts yang sudah memiliki cache | Cache tampil cepat lalu data diperbarui | Menunggu uji perangkat | Belum diuji |

## Verifikasi otomatis

Jalankan:

```bash
flutter analyze
flutter test
```

Test otomatis memverifikasi mapping model yang aman, serialisasi dirty, provider sukses/error dengan fake repository, sinkronisasi berhasil, penolakan saat offline, dan resolusi konflik.

## Bukti yang harus diambil dari perangkat

Simpan berkas berikut di `screenshots/`:

- `p1-tema-terang.png`
- `p1-tema-gelap.png`
- `p3-mode-pesawat.png`
- `p4-dirty-sebelum.png`
- `p4-dirty-sesudah.png`
- `p4-posts-offline.png`

Pastikan status bar/indikator kondisi offline terlihat pada screenshot yang relevan