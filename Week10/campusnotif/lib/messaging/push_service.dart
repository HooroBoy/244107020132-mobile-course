import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/notification_store.dart';
import '../routes.dart';
import 'payload.dart';

/// Nama resource suara notifikasi.
///
/// Berkasnya ada di `android/app/src/main/res/raw/campus_notif.wav`, disalin
/// dari `assets/mixkit-digital-quick-tone-2866.wav`. Android hanya bisa memutar
/// suara notifikasi dari resource native (`res/raw`), bukan dari aset Flutter.
const String kNotificationSoundResource = 'campus_notif';

/// Kanal notifikasi Android. Nama kanal terlihat oleh pengguna di pengaturan
/// sistem, jadi harus deskriptif dan tidak berisi karakter aneh.
///
/// id memakai akhiran `_v2`: setelan kanal **tidak dapat diubah** setelah
/// dibuat. Perangkat yang pernah menjalankan versi sebelumnya sudah memiliki
/// kanal `pengumuman` dengan suara default, sehingga suara kustom hanya berlaku
/// pada id baru. Konsekuensinya, payload dari backend wajib memakai
/// `channel_id: pengumuman_v2`.
const AndroidNotificationChannel kAnnouncementChannel =
    AndroidNotificationChannel(
  'pengumuman_v2',
  'Pengumuman Kampus',
  description: 'Notifikasi pengumuman resmi kampus.',
  importance: Importance.high,
  playSound: true,
  sound: UriAndroidNotificationSound(kNotificationSoundResource),
  showBadge: true,
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
        _messagingOverride = messaging;

  final FlutterLocalNotificationsPlugin _local;

  /// Disuntik saat test. `null` berarti memakai [FirebaseMessaging.instance].
  final FirebaseMessaging? _messagingOverride;

  /// Diselesaikan malas, bukan di konstruktor: `FirebaseMessaging.instance`
  /// memanggil `Firebase.app()` yang melempar bila Firebase belum
  /// diinisialisasi. Dengan cara ini kelas tetap bisa dibuat (dan diuji) pada
  /// mode tanpa `google-services.json`.
  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;

  /// Langganan `onTokenRefresh`, disimpan agar bisa dibatalkan saat `start()`
  /// dipanggil ulang setelah login berikutnya.
  StreamSubscription<String>? _tokenSubscription;

  /// Listener pesan FCM yang sedang aktif.
  final List<StreamSubscription<RemoteMessage>> _messageSubscriptions =
      <StreamSubscription<RemoteMessage>>[];

  /// `getInitialMessage()` mengembalikan pesan yang sama bila dipanggil ulang
  /// dalam satu proses; penanda ini mencegah deep link dibuka dua kali.
  bool _initialMessageConsumed = false;

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

    // Langganan lama dibatalkan lebih dulu: `start()` dipanggil lagi setelah
    // login berikutnya, dan tanpa ini tiap login menambah satu listener yang
    // melaporkan token yang sama berulang kali ke backend.
    await _tokenSubscription?.cancel();
    // ignore: deprecated_member_use
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (String refreshed) async {
        await onToken(refreshed);
      },
    );
  }

  /// Berlangganan topik broadcast kampus.
  Future<void> subscribeCampusTopic() =>
      _messaging.subscribeToTopic(kCampusTopic);

  Future<void> unsubscribeCampusTopic() =>
      _messaging.unsubscribeFromTopic(kCampusTopic);

  /// Memasang tiga handler sesuai app state.
  ///
  /// - foreground: sistem tidak menampilkan banner, jadi ditampilkan manual;
  ///   pesan juga dicatat ke kotak masuk lewat [onNotification];
  /// - background: banner sistem tampil, klik ditangani [onOpened];
  /// - terminated: pesan awal diambil lewat [getInitialMessage].
  ///
  /// [onOpened] menerima `messageId` agar entri kotak masuk yang sudah dilihat
  /// pengguna dapat dihapus (dianggap terbaca).
  Future<void> listenMessages({
    required void Function(String route) onRoute,
    required Future<void> Function(AppNotification notification) onNotification,
    required Future<void> Function(String? messageId, String route) onOpened,
  }) async {
    _onRoute = onRoute;

    // Sama seperti token: `listenMessages` bisa dipanggil lagi setelah login
    // berikutnya, jadi listener lama dilepas agar satu pesan tidak menampilkan
    // dua banner dan tidak tercatat dua kali.
    await _cancelMessageListeners();

    _messageSubscriptions.add(
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final String route = routeFromMessage(message.data);
        final String title = message.notification?.title ?? 'Pengumuman';
        final String body = message.notification?.body ?? '';

        await onNotification(
          AppNotification.fromMessage(
            messageId: message.messageId,
            title: title,
            body: body,
            route: route,
          ),
        );

        await showLocalNotification(title: title, body: body, route: route);
      }),
    );

    _messageSubscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        await onOpened(message.messageId, routeFromMessage(message.data));
      }),
    );

    // Hanya diproses sekali per proses: pesan awal adalah notifikasi yang
    // membuka aplikasi dari state terminated.
    if (!_initialMessageConsumed) {
      final RemoteMessage? initial = await _messaging.getInitialMessage();
      if (initial != null) {
        _initialMessageConsumed = true;
        await onOpened(initial.messageId, routeFromMessage(initial.data));
      }
    }
  }

  /// Melepas listener pesan yang sedang aktif.
  Future<void> _cancelMessageListeners() async {
    for (final StreamSubscription<RemoteMessage> subscription
        in _messageSubscriptions) {
      await subscription.cancel();
    }
    _messageSubscriptions.clear();
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
          // Suara kustom dari res/raw, bukan nada bawaan sistem.
          playSound: true,
          sound: UriAndroidNotificationSound(kNotificationSoundResource),
          enableVibration: true,
          // Launcher yang mendukung akan menampilkan titik/angka pada ikon.
          channelShowBadge: true,
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
