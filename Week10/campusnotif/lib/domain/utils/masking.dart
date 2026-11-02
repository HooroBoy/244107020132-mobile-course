/// Menyamarkan nilai rahasia (token) sebelum ditampilkan di UI atau screenshot.
///
/// Aturan "token tidak pernah tampil utuh" adalah aturan bisnis, bukan aturan
/// widget, sehingga fungsi ini hidup di `domain/` dan dipakai entity maupun
/// presentation. Token utuh tidak pernah dirender: hanya 8 karakter awal dan 4
/// karakter akhir. Nilai pendek disamarkan seluruhnya agar tidak bisa ditebak.
String maskSecret(String value) {
  if (value.length <= 12) return '••••••';
  return '${value.substring(0, 8)}••••${value.substring(value.length - 4)}';
}
