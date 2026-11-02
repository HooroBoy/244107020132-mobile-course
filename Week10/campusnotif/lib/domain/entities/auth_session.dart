import '../utils/masking.dart';

/// Sesi pengguna: pasangan token + identitas pemilik sesi.
///
/// Bentuknya meniru respons Firebase Auth (`getIdToken` + `refreshToken`)
/// maupun respons REST API sendiri, sehingga penggantian sumber token tidak
/// mengubah lapisan atas.
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
  String get maskedAccess => maskSecret(access);

  AuthSession copyWith({String? access, String? refresh, String? email}) {
    return AuthSession(
      access: access ?? this.access,
      refresh: refresh ?? this.refresh,
      email: email ?? this.email,
    );
  }
}
