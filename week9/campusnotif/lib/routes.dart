/// Satu sumber kebenaran untuk seluruh path aplikasi.
///
/// GoRouter dan handler FCM (deep link dari `data.route`) wajib memakai
/// konstanta di sini, bukan string literal, supaya rute tidak pernah
/// berbeda antara navigasi biasa dan notifikasi.
abstract final class Routes {
  static const String login = '/login';
  static const String home = '/';

  /// Pola rute dengan parameter, dipakai saat mendaftarkan GoRoute.
  static const String announcementPattern = '/pengumuman/:id';

  /// Nama parameter pada [announcementPattern].
  static const String announcementIdParam = 'id';

  /// Rute konkret untuk satu pengumuman.
  static String announcement(String id) => '/pengumuman/$id';
}
