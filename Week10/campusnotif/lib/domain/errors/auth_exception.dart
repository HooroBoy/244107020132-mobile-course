/// Kegagalan autentikasi dengan pesan yang aman ditampilkan ke pengguna.
///
/// Kode mentah dari penyedia auth (`wrong-password`, `core/no-app`) tidak boleh
/// naik ke UI, sehingga implementasi repository menerjemahkannya lebih dulu
/// menjadi [AuthException].
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
