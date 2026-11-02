import '../../entities/auth_session.dart';
import '../../repositories/session_repository.dart';

/// Membaca sesi tersimpan saat aplikasi dibuka.
///
/// Sesi setengah jadi (access ada, refresh hilang) adalah data tidak konsisten:
/// dibersihkan dan pengguna diminta login ulang. Aturan ini sengaja hidup di
/// domain, bukan di penyimpanan.
class RestoreSessionUseCase {
  const RestoreSessionUseCase(this._sessions);

  final SessionRepository _sessions;

  Future<AuthSession?> call() async {
    final AuthSession? session = await _sessions.read();
    if (session == null) return null;

    if (session.access.isEmpty || session.refresh.isEmpty) {
      await _sessions.clear();
      return null;
    }

    return session;
  }
}
