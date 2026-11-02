/// Satu sumber kebenaran untuk seluruh path aplikasi.
///
/// `Routes` berada di lapisan domain karena rute adalah kontrak: notifikasi
/// membawa rute, router membuka rute, dan keduanya harus sepakat. Menaruhnya di
/// presentation akan memaksa lapisan data meng-import UI.
abstract final class Routes {
  static const String login = '/login';
  static const String home = '/';

  /// Daftar notifikasi yang belum dibaca.
  static const String notifications = '/notifikasi';

  /// Pola rute dengan parameter, dipakai saat mendaftarkan GoRoute.
  static const String announcementPattern = '/pengumuman/:id';

  /// Nama parameter pada [announcementPattern].
  static const String announcementIdParam = 'id';

  /// Rute konkret untuk satu pengumuman.
  static String announcement(String id) => '/pengumuman/$id';

  /// Rute aman untuk navigasi.
  ///
  /// Nilai kosong diarahkan ke beranda dan garis miring di depan ditambahkan
  /// bila hilang, karena backend kadang mengirim `pengumuman/3` alih-alih
  /// `/pengumuman/3`.
  static String sanitize(String? route) {
    if (route == null || route.trim().isEmpty) return home;
    final String trimmed = route.trim();
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }
}
