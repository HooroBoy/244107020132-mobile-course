/// Waktu relatif singkat untuk daftar notifikasi, mis. "baru saja", "5 mnt lalu".
///
/// Fungsi murni supaya bisa diuji tanpa widget. [now] bisa diisi agar hasilnya
/// deterministik pada test.
String relativeTime(DateTime at, {DateTime? now}) {
  final DateTime reference = now ?? DateTime.now();
  final Duration diff = reference.difference(at);

  // Waktu di masa depan (jam perangkat mundur) ditampilkan apa adanya.
  if (diff.isNegative) return 'baru saja';

  if (diff.inSeconds < 60) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hr lalu';

  final String day = at.day.toString().padLeft(2, '0');
  final String month = at.month.toString().padLeft(2, '0');
  return '$day/$month/${at.year}';
}
