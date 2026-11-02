import '../entities/auth_session.dart';

/// Penyimpanan sesi di perangkat.
///
/// Kontraknya berbicara dalam [AuthSession], bukan tiga kunci terpisah, sehingga
/// lapisan atas tidak perlu tahu berapa banyak kunci yang dipakai atau di mana
/// token disimpan. Implementasi produksi memakai secure storage.
abstract interface class SessionRepository {
  /// Sesi tersimpan, atau `null` bila belum login.
  ///
  /// Sesi yang tidak lengkap (mis. refresh kosong) tetap dikembalikan apa
  /// adanya: yang berhak menilai sesi rusak adalah lapisan domain
  /// (`RestoreSessionUseCase`), bukan penyimpanan.
  Future<AuthSession?> read();

  Future<void> save(AuthSession session);

  /// Hapus seluruh sesi (logout, atau refresh token sudah mati).
  Future<void> clear();
}
