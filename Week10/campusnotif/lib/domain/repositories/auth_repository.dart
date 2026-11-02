import '../entities/auth_session.dart';

/// Kontrak sumber autentikasi.
///
/// `signOut` sengaja berada di interface ini, bukan di interface tambahan yang
/// diperiksa dengan `is` saat runtime. Dengan begitu setiap implementasi
/// (Firebase, mock, fake test) benar-benar bisa menggantikan satu sama lain
/// tanpa kejutan — inilah bentuk Liskov Substitution yang dijaga.
abstract interface class AuthRepository {
  Future<AuthSession> login({
    required String email,
    required String password,
  });

  /// Menukar refresh token dengan access token baru.
  ///
  /// Melempar `AuthException` bila sesi tidak bisa diperpanjang; pemanggil
  /// wajib membersihkan sesi dan memaksa login ulang.
  Future<String> refresh(String refreshToken);

  /// Menghapus sesi di sisi penyedia auth (bila ada).
  Future<void> signOut();
}
