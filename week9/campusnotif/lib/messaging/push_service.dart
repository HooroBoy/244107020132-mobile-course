import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../routes.dart';
import 'payload.dart';

/// Kanal notifikasi Android. Nama kanal terlihat oleh pengguna di pengaturan
/// sistem, jadi harus deskriptif dan tidak berisi karakter aneh.
const AndroidNotificationChannel kAnnouncementChannel =
    AndroidNotificationChannel(
  'pengumuman',
  'Pengumuman Kampus',
  description: 'Notifikasi pengumuman resmi kampus.',
  importance: Importance.high,
);

/// Topik broadcast untuk seluruh mahasiswa.
const String kCampusTopic = 'pengumuman-kampus';

/// Pembungkus FCM + local notification.
///
/// Kelas ini tidak tahu apa-apa soal UI atau router: navigasi dan pengiriman
/// token ke backend diserahkan lewat callback, sehingga mudah diganti saat
/// backend nyata tersedia.
class PushService {
  PushService({
    FlutterLocalNotificationsPlugin? local,
    FirebaseMessaging? messaging,
  })  : _local = local ?? FlutterLocalNotificationsPlugin(),
        _messaging = messaging ?? FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _local;
  final FirebaseMessaging _messaging;

  /// Route dari ketukan notifikasi yang belum sempat diproses (mis. diketuk
  /// saat aplikasi baru dibuka dari terminated).
  String? pendingDeepLink;

  bool _localReady = false;

  /// Dipasang oleh [listenMessages]; dipakai agar ketukan banner saat
  /// foreground bisa langsung bernavigasi tanpa menunggu siklus restart.
  void Function(String route)? _onRoute;

  /// Menyiapkan local notification (dipakai untuk banner saat foreground).
  Future<void> initLocalNotifications() async {
    if (_localReady) return;

    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // Izin iOS diminta lewat FirebaseMessaging.requestPermission agar
        // satu jalur dengan Android; di sini jangan minta dua kali.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _local.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Ketukan pada banner lokal (kasus foreground).
        final String route = sanitizeRoute(response.payload);
        final void Function(String route)? handler = _onRoute;
        if (handler != null) {
          handler(route);
        } else {
          pendingDeepLink = route;
        }
      },
    );

    // Kanal harus dibuat eksplisit di Android 8+ agar importance-nya benar.
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(kAnnouncementChannel);

    _localReady = true;
  }

  /// Meminta izin notifikasi. Android 13+ dan iOS memerlukan ini saat runtime.
  Future<bool> requestPermission() async {
    final NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Mengambil token perangkat saat ini lalu memantau perubahannya.
  ///
  /// [onToken] wajib mengirim token ke backend. Tanpa `onTokenRefresh`,
  /// backend akan menyimpan token basi setelah reinstall / clear data, dan
  /// notifikasi berhenti sampai di perangkat pengguna.
  ///
  /// Catatan versi: `firebase_messaging` 17 menandai `getToken` dan
  /// `onTokenRefresh` sebagai deprecated dan mengarahkan ke `register()` /
  /// `onRegistered` (Firebase Installation ID). Keduanya tetap dipakai karena
  /// (1) codelab mewajibkan `getToken` + `onTokenRefresh`, dan (2) pengiriman
  /// dari Firebase Console masih menargetkan FCM registration token, bukan
  /// FID. Migrasi ke FID didokumentasikan di docs/ai-challenge.md.
  Future<void> initFcmToken({
    required Future<void> Function(String token) onToken,
  }) async {
    // ignore: deprecated_member_use
    final String? token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await onToken(token);
    }

    // ignore: deprecated_member_use
    _messaging.onTokenRefresh.listen((String refreshed) async {
      await onToken(refreshed);
    });
  }

  /// Berlangganan topik broadcast kampus.
  Future<void> subscribeCampusTopic() =>
      _messaging.subscribeToTopic(kCampusTopic);

  Future<void> unsubscribeCampusTopic() =>
      _messaging.unsubscribeFromTopic(kCampusTopic);

  /// Memasang tiga handler sesuai app state.
  ///
  /// - foreground: sistem tidak menampilkan banner, jadi ditampilkan manual;
  /// - background: banner sistem tampil, klik ditangani [onMessageOpenedApp];
  /// - terminated: pesan awal diambil lewat [getInitialMessage].
  Future<void> listenMessages({
    required void Function(String route) onRoute,
  }) async {
    _onRoute = onRoute;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final String route = routeFromMessage(message.data);
      await showLocalNotification(
        title: message.notification?.title ?? 'Pengumuman',
        body: message.notification?.body ?? '',
        route: route,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      onRoute(routeFromMessage(message.data));
    });

    final RemoteMessage? initial = await _messaging.getInitialMessage();
    if (initial != null) {
      onRoute(routeFromMessage(initial.data));
    }
  }

  /// Menampilkan banner lokal. Dipakai untuk foreground, dan juga bisa dipakai
  /// untuk notifikasi uji manual dari dalam aplikasi.
  Future<void> showLocalNotification({
    required String title,
    required String body,
    required String route,
  }) async {
    await initLocalNotifications();

    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      payload: route,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          kAnnouncementChannel.id,
          kAnnouncementChannel.name,
          channelDescription: kAnnouncementChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Membaca dan menghapus route yang tertunda. Dipanggil setelah router siap.
  String? consumePendingDeepLink() {
    final String? route = pendingDeepLink;
    pendingDeepLink = null;
    return route;
  }

  /// Route aman untuk navigasi: payload kosong diarahkan ke beranda.
  static String sanitizeRoute(String? route) {
    if (route == null || route.trim().isEmpty) return Routes.home;
    final String trimmed = route.trim();
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  /// Nama platform untuk laporan ke backend.
  static String get platformName {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }
}
