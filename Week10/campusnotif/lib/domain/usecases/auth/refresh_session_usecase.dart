import '../../entities/auth_session.dart';
import '../../errors/auth_exception.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/session_repository.dart';

/// Menukar refresh token dengan access token baru tanpa mengubah identitas.
class RefreshSessionUseCase {
  const RefreshSessionUseCase(this._auth, this._sessions);

  final AuthRepository _auth;
  final SessionRepository _sessions;

  /// Melempar [AuthException] bila sesi tidak bisa diperpanjang; pemanggil wajib
  /// membersihkan sesi dan memaksa login ulang.
  Future<AuthSession> call() async {
    final AuthSession? current = await _sessions.read();
    if (current == null || current.refresh.isEmpty) {
      throw const AuthException('Refresh token hilang atau kedaluwarsa');
    }

    final String renewed = await _auth.refresh(current.refresh);
    // Refresh token lama dipertahankan; hanya access yang diperbarui.
    final AuthSession next = current.copyWith(access: renewed);
    await _sessions.save(next);
    return next;
  }
}
