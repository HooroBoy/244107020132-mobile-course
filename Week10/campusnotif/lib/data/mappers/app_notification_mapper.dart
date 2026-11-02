import '../../domain/entities/app_notification.dart';

/// Pemetaan entity ke format penyimpanan.
///
/// Ditempatkan di lapisan data karena bentuk JSON adalah detail penyimpanan:
/// entity di `domain/` tetap murni dan bisa dipakai penyimpanan lain (mis.
/// SQLite) tanpa mengubah aturan bisnis.
Map<String, dynamic> appNotificationToJson(AppNotification notification) {
  return <String, dynamic>{
    'id': notification.id,
    'title': notification.title,
    'body': notification.body,
    'route': notification.route,
    'received_at': notification.receivedAt.toIso8601String(),
  };
}

/// Mengembalikan `null` untuk data rusak, bukan melempar exception.
///
/// Satu entri yang korup tidak boleh membuat seluruh kotak masuk hilang.
AppNotification? appNotificationFromJson(Map<String, dynamic> json) {
  final Object? id = json['id'];
  final Object? route = json['route'];
  if (id is! String || id.isEmpty || route is! String || route.isEmpty) {
    return null;
  }

  final Object? title = json['title'];
  final Object? body = json['body'];
  final Object? receivedAt = json['received_at'];

  return AppNotification(
    id: id,
    title: title is String && title.isNotEmpty
        ? title
        : AppNotification.fallbackTitle,
    body: body is String ? body : '',
    route: route,
    receivedAt: DateTime.tryParse('$receivedAt') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}
