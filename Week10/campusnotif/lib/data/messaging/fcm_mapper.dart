import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/entities/app_notification.dart';
import '../../domain/routes.dart';

/// Mengekstrak tujuan navigasi dari `data` payload FCM.
///
/// Fungsi murni tanpa dependensi Firebase supaya bisa diunit-test. Aturan
/// penambahan garis miring ada di [Routes.sanitize], satu tempat dengan aturan
/// rute lain.
String routeFromMessage(Map<String, dynamic> data) {
  final Object? raw = data['route'];
  return Routes.sanitize(raw is String ? raw : null);
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

/// Menerjemahkan pesan FCM menjadi entity domain.
///
/// Ini satu-satunya tempat yang tahu bentuk `RemoteMessage`, sehingga lapisan
/// atas (use case, controller, UI) tidak pernah menyentuh tipe plugin.
AppNotification appNotificationFromMessage(RemoteMessage message) {
  return AppNotification.create(
    messageId: message.messageId,
    title: message.notification?.title ?? AppNotification.fallbackTitle,
    body: message.notification?.body ?? '',
    route: routeFromMessage(message.data),
  );
}
