import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Satu-satunya pintu keluar-masuk token.
///
/// Aturan proyek: tidak ada kode lain yang boleh menyentuh
/// [FlutterSecureStorage] secara langsung, dan token tidak pernah ditulis ke
/// SharedPreferences, log, atau state yang ikut ter-screenshot.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';
  static const String _emailKey = 'session_email';

  /// Menyimpan sesi. Refresh token hanya boleh hidup di secure storage.
  Future<void> save({
    required String access,
    required String refresh,
    String? email,
  }) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
    if (email != null) {
      await _storage.write(key: _emailKey, value: email);
    }
  }

  Future<String?> readAccess() => _storage.read(key: _accessKey);
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);
  Future<String?> readEmail() => _storage.read(key: _emailKey);

  /// Dipakai guard route untuk memutuskan perlu login atau tidak.
  Future<bool> hasSession() async => await readAccess() != null;

  /// Hapus seluruh sesi (logout, atau refresh token sudah mati).
  Future<void> clear() => _storage.deleteAll();
}
