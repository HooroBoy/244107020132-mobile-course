import '../../constants.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/device_repository.dart';
import '../../repositories/push_messaging.dart';
import '../../repositories/session_repository.dart';

/// Keluar dari semua kanal notifikasi lalu hapus sesi.
///
/// Urutannya adalah bagian dari aturan bisnis: `unregister` memakai header
/// `Authorization` dari sesi yang masih ada. Kalau sesi dihapus lebih dulu,
/// backend menolak dengan 401 dan token perangkat tertinggal — pengguna yang
/// sudah logout tetap menerima notifikasi.
///
/// Dulu urutan ini tersebar di `HomePage`, `PushController`, dan `AuthNotifier`;
/// sekarang ada di satu tempat yang bisa diuji.
class LogoutUseCase {
  const LogoutUseCase(
    this._auth,
    this._sessions,
    this._devices,
    this._push,
  );

  final AuthRepository _auth;
  final SessionRepository _sessions;
  final DeviceRepository _devices;
  final PushMessaging _push;

  Future<void> call() async {
    final String? token = await _push.currentToken();
    if (token != null && token.isNotEmpty) {
      await _devices.unregister(token: token);
    }

    try {
      await _push.unsubscribeTopic(kCampusTopic);
    } on Object {
      // Gagal berhenti berlangganan tidak boleh menghalangi logout.
    }

    // Tanpa signOut, SDK Firebase memulihkan sesinya sendiri saat aplikasi
    // dibuka sehingga pengguna tampak "tidak pernah logout".
    await _auth.signOut();
    await _sessions.clear();
  }
}
