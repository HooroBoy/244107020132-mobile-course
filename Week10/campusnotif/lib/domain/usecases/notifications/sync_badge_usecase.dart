import '../../repositories/app_badge.dart';

/// Menyelaraskan angka badge ikon aplikasi dengan jumlah notifikasi belum dibaca.
///
/// Dipisah dari use case lain karena satu alasan perubahan: bagaimana angka
/// badge dihitung dan dipasang. Ketiga use case kotak masuk memakainya lewat
/// komposisi, bukan menyalin kode yang sama.
class SyncBadgeUseCase {
  const SyncBadgeUseCase(this._badge);

  final AppBadge _badge;

  Future<void> call(int unreadCount) async {
    // Badge bersifat tambahan: kegagalannya tidak boleh terlihat pengguna.
    await _badge.setCount(unreadCount < 0 ? 0 : unreadCount);
  }
}
