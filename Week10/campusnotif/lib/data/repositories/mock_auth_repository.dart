import '../../domain/entities/auth_session.dart';
import '../../domain/errors/auth_exception.dart';
import '../../domain/repositories/auth_repository.dart';

/// Implementasi offline untuk praktikum dan test.
///
/// Menerima email apa pun yang mengandung `@` dengan kata sandi minimal 6
/// karakter. Token yang dihasilkan palsu dan hanya untuk mendemonstrasikan alur
/// penyimpanan aman + refresh.
///
/// `signOut` diimplementasikan sebagai no-op, sehingga kelas ini tetap bisa
/// menggantikan `FirebaseAuthRepository` tanpa pengecualian tipe.
class MockAuthRepository implements AuthRepository {
  const MockAuthRepository();

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!email.contains('@') || password.length < 6) {
      throw const AuthException('Email atau kata sandi tidak valid');
    }

    return AuthSession(
      access: 'mock-access-for-$email',
      refresh: 'mock-refresh-for-$email',
      email: email,
    );
  }

  @override
  Future<String> refresh(String refreshToken) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (refreshToken.trim().isEmpty) {
      throw const AuthException('Refresh token hilang atau kedaluwarsa');
    }
    if (refreshToken == 'mock-refresh-revoked') {
      throw const AuthException('Refresh token ditolak server');
    }

    return 'mock-access-renewed-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<void> signOut() async {
    // Tidak ada sesi server yang perlu dihapus pada mode mock.
  }
}
