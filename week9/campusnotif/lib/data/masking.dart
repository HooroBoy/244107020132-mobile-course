/// Menyamarkan nilai rahasia (token) sebelum ditampilkan di UI atau screenshot.
///
/// Token utuh tidak pernah dirender: hanya 8 karakter awal dan 4 karakter akhir.
/// Nilai pendek disamarkan seluruhnya agar tidak bisa ditebak.
String maskSecret(String value) {
  if (value.length <= 12) return '••••••';
  return '${value.substring(0, 8)}••••${value.substring(value.length - 4)}';
}
