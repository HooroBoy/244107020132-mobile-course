/// Satu pengumuman yang diterima aplikasi lewat notifikasi.
///
/// Entity murni: tidak tahu FCM, penyimpanan, maupun widget. Serialisasi ada di
/// `data/mappers/app_notification_mapper.dart` supaya aturan bisnis tidak
/// tercampur format berkas.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    required this.receivedAt,
  });

  /// Membuat entri dari payload notifikasi.
  ///
  /// `messageId` dipakai sebagai id bila tersedia, supaya pesan yang sama tidak
  /// tercatat dua kali ketika FCM mengirim ulang.
  factory AppNotification.create({
    String? messageId,
    required String title,
    required String body,
    required String route,
    DateTime? receivedAt,
  }) {
    final DateTime at = receivedAt ?? DateTime.now();
    final String trimmedId = messageId?.trim() ?? '';
    return AppNotification(
      id: trimmedId.isEmpty ? '${at.microsecondsSinceEpoch}-$route' : trimmedId,
      title: title.trim().isEmpty ? fallbackTitle : title.trim(),
      body: body.trim(),
      route: route,
      receivedAt: at,
    );
  }

  /// Judul pengganti bila payload tidak membawa judul.
  static const String fallbackTitle = 'Pengumuman';

  final String id;
  final String title;
  final String body;

  /// Rute deep link yang dibuka saat notifikasi diketuk.
  final String route;
  final DateTime receivedAt;
}
