import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/errors/auth_exception.dart';
import '../../domain/repositories/auth_repository.dart';
import '../errors/firebase_auth_messages.dart';

/// Penanda refresh token untuk platform yang tidak mengekspos refresh token
/// (mis. web). Nilainya tidak pernah dipakai untuk menukar token: perpanjangan
/// dilakukan lewat `User.getIdToken(forceRefresh: true)`.
///
/// Disimpan agar invariant "sesi punya access + refresh" tetap berlaku tanpa
/// berpura-pura memiliki token rahasia.
const String kOpaqueRefreshToken = 'firebase:getIdToken';

/// Implementasi produksi: login lewat Firebase Authentication.
///
/// Alur: `signInWithEmailAndPassword` → `User.getIdToken()` sebagai access token
/// → `User.refreshToken` (bila tersedia) untuk disimpan aman.
class FirebaseAuthRepository implements AuthRepository {
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
        email: user.email,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(authMessageFor(error.code, error.message));
    }
  }

  /// Firebase menyimpan sesinya sendiri; perpanjangan memakai
  /// `User.getIdToken(forceRefresh: true)`. Parameter [refreshToken] hanya
  /// penanda, bukan rahasia yang ditukar ke server.
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
