import '../routes.dart';

/// Mengekstrak tujuan navigasi dari `data` payload FCM.
///
/// Fungsi murni tanpa dependensi Firebase supaya bisa diunit-test. Aturannya:
/// - payload kosong / tanpa `route` -> beranda;
/// - `route` tanpa garis miring di depan -> ditambahkan otomatis, karena
///   backend kadang mengirim `pengumuman/3` alih-alih `/pengumuman/3`.
String routeFromMessage(Map<String, dynamic> data) {
  final Object? raw = data['route'];
  final String route = raw is String ? raw.trim() : '';

  if (route.isEmpty) return Routes.home;
  if (route.startsWith('/')) return route;
  return '/$route';
}

/// Mengambil id pengumuman dari payload: utamakan `data.id`, jika tidak ada
/// ambil segmen terakhir dari `data.route`.
String? idFromMessage(Map<String, dynamic> data) {
  final Object? rawId = data['id'];
  if (rawId != null && rawId.toString().trim().isNotEmpty) {
    return rawId.toString().trim();
  }

  final String route = routeFromMessage(data);
  if (route == Routes.home) return null;

  final List<String> segments =
      route.split('/').where((String s) => s.isNotEmpty).toList();
  return segments.isEmpty ? null : segments.last;
}
