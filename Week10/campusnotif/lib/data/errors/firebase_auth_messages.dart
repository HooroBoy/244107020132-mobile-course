/// Terjemahan kode error Firebase Auth menjadi kalimat yang layak dibaca.
///
/// Kode mentah (`wrong-password`, `too-many-requests`) tidak boleh muncul di UI.
/// Pemetaan berada di lapisan data karena hanya lapisan ini yang mengenal kode
/// milik penyedia auth.
String authMessageFor(String code, String? fallback) {
  switch (code) {
    case 'invalid-email':
      return 'Format email tidak valid.';
    case 'user-not-found':
      return 'Email belum terdaftar.';
    case 'wrong-password':
      return 'Kata sandi salah.';
    case 'invalid-credential':
      return 'Email atau kata sandi tidak valid.';
    case 'user-disabled':
      return 'Akun ini dinonaktifkan. Hubungi admin kampus.';
    case 'too-many-requests':
      return 'Terlalu banyak percobaan login. Coba lagi nanti.';
    case 'network-request-failed':
      return 'Tidak ada koneksi internet.';
    case 'operation-not-allowed':
      return 'Login email/kata sandi belum diaktifkan di Firebase Console.';
    case 'weak-password':
      return 'Kata sandi terlalu lemah (minimal 6 karakter).';
    case 'requires-recent-login':
      return 'Sesi terlalu lama. Silakan login ulang.';
    default:
      final String detail = fallback?.trim() ?? '';
      return detail.isEmpty ? 'Login gagal. Coba lagi.' : 'Login gagal: $detail';
  }
}
