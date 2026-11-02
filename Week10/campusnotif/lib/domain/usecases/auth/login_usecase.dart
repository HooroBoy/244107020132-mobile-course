import '../../entities/auth_session.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/session_repository.dart';

/// Login lalu simpan sesi.
///
/// Satu aksi bisnis yang tadinya menumpang di `AuthNotifier`: controller tidak
/// perlu tahu urutan "login → simpan token".
class LoginUseCase {
  const LoginUseCase(this._auth, this._sessions);

  final AuthRepository _auth;
  final SessionRepository _sessions;

  Future<AuthSession> call({
    required String email,
    required String password,
  }) async {
    final AuthSession session = await _auth.login(
      email: email,
      password: password,
    );
    await _sessions.save(session);
    return session;
  }
}
