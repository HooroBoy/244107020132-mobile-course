/// Angka badge pada ikon aplikasi.
///
/// Kontraknya satu method saja (Interface Segregation): pemakai hanya butuh
/// "setel angka", bukan seluruh kemampuan plugin badge.
abstract interface class AppBadge {
  /// Nilai negatif diperlakukan sebagai 0. Kegagalan platform (launcher tidak
  /// mendukung, web, test) ditelan implementasi dan tidak boleh terlihat
  /// pengguna.
  Future<void> setCount(int count);
}
