import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/push_messaging.dart';
import '../../domain/routes.dart';
import 'fcm_mapper.dart';

/// Nama resource suara notifikasi.
///
/// Berkasnya ada di `android/app/src/main/res/raw/campus_notif.wav`, disalin dari
/// `assets/mixkit-digital-quick-tone-2866.wav`. Android hanya bisa memutar suara
/// notifikasi dari resource native (`res/raw`), bukan dari aset Flutter.
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

/// Implementasi [PushMessaging] di atas FCM + `flutter_local_notifications`.
///
/// Seluruh tipe plugin berhenti di kelas ini: lapisan domain hanya menerima
/// [AppNotification] dan `String` token.
class FcmPushMessaging implements PushMessaging {
  FcmPushMessaging({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? local,
  })  : _messagingOverride = messaging,
        _local = local ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _local;

  /// Disuntik saat test. `null` berarti memakai [FirebaseMessaging.instance].
  final FirebaseMessaging? _messagingOverride;

  /// Diselesaikan malas, bukan di konstruktor: `FirebaseMessaging.instance`
  /// memanggil `Firebase.app()` yang melempar bila Firebase belum
  /// diinisialisasi. Dengan cara ini kelas tetap bisa dibuat (dan diuji) pada
  /// mode tanpa `google-services.json`.
  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;

  /// Ketukan pada banner lokal diteruskan sebagai rute.
  final StreamController<String> _bannerTaps =
      StreamController<String>.broadcast();

  bool _localReady = false;

  /// `getInitialMessage()` mengembalikan pesan yang sama bila dipanggil ulang
  /// dalam satu proses; penanda ini mencegah deep link dibuka dua kali.
  bool _initialMessageConsumed = false;

  @override
  Future<void> prepare() async {
    if (_localReady) return;

    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // Izin iOS diminta lewat `requestPermission` agar satu jalur dengan
        // Android; di sini jangan minta dua kali.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _local.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _bannerTaps.add(Routes.sanitize(response.payload));
      },
    );

    // Kanal harus dibuat eksplisit di Android 8+ agar importance dan suara benar.
    // Kalau dibiarkan dibuat otomatis oleh pesan pertama, suara kustom tidak akan
    // pernah terpasang karena setelan kanal tidak bisa diubah setelah ada.
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(kAnnouncementChannel);

    _localReady = true;
  }

  @override
  Future<bool> requestPermission() async {
    final NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> currentToken() async {
    // ignore: deprecated_member_use
    final String? token = await _messaging.getToken();
    return token != null && token.isNotEmpty ? token : null;
  }

  @override
  Stream<String> get tokenRefresh {
    // ignore: deprecated_member_use
    return _messaging.onTokenRefresh;
  }

  @override
  Stream<AppNotification> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(appNotificationFromMessage);

  @override
  Stream<AppNotification> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map(appNotificationFromMessage);

  @override
  Stream<String> get bannerTaps => _bannerTaps.stream;

  @override
  Future<AppNotification?> initialMessage() async {
    if (_initialMessageConsumed) return null;

    final RemoteMessage? message = await _messaging.getInitialMessage();
    if (message == null) return null;

    _initialMessageConsumed = true;
    return appNotificationFromMessage(message);
  }

  @override
  Future<void> subscribeTopic(String topic) =>
      _messaging.subscribeToTopic(topic);

  @override
  Future<void> unsubscribeTopic(String topic) =>
      _messaging.unsubscribeFromTopic(topic);

  @override
  Future<void> showBanner(AppNotification notification) async {
    await prepare();

    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: notification.title,
      body: notification.body,
      payload: notification.route,
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
}
