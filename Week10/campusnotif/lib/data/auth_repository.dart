import 'package:firebase_auth/firebase_auth.dart';

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

/// Kontrak sumber autentikasi.
///
/// Ada dua implementasi:
/// - [FirebaseAuthRepository] — dipakai saat Firebase siap (produksi);
/// - [MockAuthRepository] — dipakai saat Firebase tidak dikonfigurasi dan oleh
///   test, sehingga aplikasi tetap bisa dijalankan tanpa `google-services.json`.
///
/// Pemilihan implementasi dilakukan `authRepositoryProvider`, bukan di UI.
abstract class AuthRepository {
  Future<AuthSession> login({
    required String email,
    required String password,
  });

  /// Menukar refresh token dengan access token baru.
  ///
  /// Melempar [AuthException] bila sesi tidak bisa diperpanjang; pemanggil
  /// wajib membersihkan sesi dan memaksa login ulang.
  Future<String> refresh(String refreshToken);
}

/// Kemampuan tambahan untuk sumber auth yang punya sesi di sisi server.
///
/// Dipisah dari [AuthRepository] agar implementasi tanpa sesi server (mock)
/// tidak dipaksa mengimplementasikannya.
abstract interface class SignOutCapable {
  Future<void> signOut();
}

/// Penanda refresh token untuk platform yang tidak mengekspos refresh token
/// (mis. web). Nilainya tidak pernah dipakai untuk menukar token: perpanjangan
/// dilakukan lewat `User.getIdToken(forceRefresh: true)`.
///
/// Disimpan agar invariant "sesi punya access + refresh" tetap berlaku tanpa
/// berpura-pura memiliki token rahasia.
const String kOpaqueRefreshToken = 'firebase:getIdToken';

/// Implementasi produksi: login lewat Firebase Authentication.
///
/// Alur: `signInWithEmailAndPassword` → `User.getIdToken()` sebagai access
/// token → `User.refreshToken` (bila tersedia) untuk disimpan aman.
class FirebaseAuthRepository implements AuthRepository, SignOutCapable {
  FirebaseAuthRepository({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential =
          await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = credential.user;
      if (user == null) {
        throw const AuthException(
          'Login berhasil tetapi data pengguna tidak tersedia.',
        );
      }

      final String? access = await user.getIdToken();
      if (access == null || access.isEmpty) {
        throw const AuthException('Gagal memperoleh ID token dari Firebase.');
      }

      return AuthSession(
        access: access,
        // Firebase tidak mengekspos refresh token di semua platform.
        refresh: user.refreshToken ?? kOpaqueRefreshToken,
        email: user.email ?? email.trim(),
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(authMessageFor(error.code, error.message));
    }
  }

  /// Memperbarui access token lewat Firebase.
  ///
  /// Parameter [refreshToken] sengaja tidak dipakai: Firebase menyimpan sesi
  /// sendiri dan satu-satunya cara sah memperbarui token adalah meminta ulang
  /// ke SDK. Parameter dipertahankan agar kontrak [AuthRepository] tetap sama.
  @override
  Future<String> refresh(String refreshToken) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(
        'Sesi Firebase tidak ditemukan. Silakan login ulang.',
      );
    }

    try {
      final String? renewed = await user.getIdToken(true);
      if (renewed == null || renewed.isEmpty) {
        throw const AuthException('Firebase tidak mengembalikan ID token baru.');
      }
      return renewed;
    } on FirebaseAuthException catch (error) {
      throw AuthException(authMessageFor(error.code, error.message));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}


/// Terjemahan kode error Firebase Auth menjadi kalimat yang layak dibaca.
///
/// Kode mentah (`wrong-password`, `too-many-requests`) tidak boleh muncul di UI.
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

/// Implementasi offline untuk praktikum dan test.
///
/// Menerima email apa pun yang mengandung `@` dengan kata sandi minimal 6
/// karakter. Token yang dihasilkan palsu dan hanya untuk mendemonstrasikan
/// alur penyimpanan aman + refresh.
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
}

/// Kegagalan autentikasi dengan pesan yang aman ditampilkan ke pengguna.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
