import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/session_repository.dart';

/// Implementasi [SessionRepository] di atas `flutter_secure_storage`.
///
/// Satu-satunya kelas di seluruh aplikasi yang boleh menyentuh secure storage.
/// Nilainya memakai Keystore (Android) / Keychain (iOS), sehingga tidak ikut
/// tersalin lewat backup dan tidak terbaca sebagai berkas biasa.
class SecureSessionRepository implements SessionRepository {
  SecureSessionRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';
  static const String _emailKey = 'session_email';

  @override
  Future<AuthSession?> read() async {
    final String? access = await _storage.read(key: _accessKey);
    if (access == null || access.isEmpty) return null;

    // Sesi tidak lengkap tetap dikembalikan apa adanya: yang menilai sesi rusak
    // adalah `RestoreSessionUseCase`, bukan penyimpanan.
    final String? refresh = await _storage.read(key: _refreshKey);

    return AuthSession(
      access: access,
      refresh: refresh ?? '',
      email: await _storage.read(key: _emailKey),
    );
  }

  @override
  Future<void> save(AuthSession session) async {
    await _storage.write(key: _accessKey, value: session.access);
    await _storage.write(key: _refreshKey, value: session.refresh);

    final String? email = session.email;
    if (email != null) {
      await _storage.write(key: _emailKey, value: email);
    }
  }

  @override
  Future<void> clear() => _storage.deleteAll();
}
