import 'masking.dart';

/// Hasil login: pasangan token + identitas pemilik sesi.
///
/// Ini meniru bentuk respons Firebase Auth (`getIdToken` + `getRefreshToken`)
/// maupun respons REST API sendiri, sehingga penggantian sumber token nanti
/// tidak mengubah lapisan UI.
class AuthSession {
  const AuthSession({
    required this.access,
    required this.refresh,
    this.email,
  });

  final String access;
  final String refresh;
  final String? email;

  /// Versi aman untuk ditampilkan / difoto: hanya potongan awal dan akhir.
  /// Token utuh tidak pernah masuk log atau screenshot.
  String get maskedAccess => maskSecret(access);
}

/// Repository autentikasi.
///
/// Saat ini memakai mock agar codelab berjalan tanpa backend. Titik ganti ke
/// Firebase Auth sudah ditandai di [login]: pola repository dan token refresh
/// tetap sama, hanya sumber token yang berubah.
class AuthRepository {
  const AuthRepository();

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!email.contains('@') || password.length < 6) {
      throw const AuthException('Email atau kata sandi tidak valid');
    }

    // GANTI titik ini dengan FirebaseAuth.instance.signInWithEmailAndPassword
    // atau GoogleSignIn saat project Firebase sudah siap.
    return AuthSession(
      access: 'mock-access-for-$email',
      refresh: 'mock-refresh-for-$email',
      email: email,
    );
  }

  /// Menukar refresh token dengan access token baru.
  ///
  /// Melempar [AuthException] bila refresh token tidak ada / sudah mati;
  /// pemanggil wajib membersihkan sesi dan memaksa login ulang.
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
}

/// Kegagalan autentikasi dengan pesan yang aman ditampilkan ke pengguna.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
