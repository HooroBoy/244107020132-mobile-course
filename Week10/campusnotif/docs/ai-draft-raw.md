# Output mentah draf AI (sebelum diperbaiki)

Dihasilkan subagent AI dari prompt codelab, tanpa akses ke implementasi
proyek ini. Disimpan apa adanya sebagai bukti untuk AI Challenge.

> Catatan: baris `import ../router/app_router.dart` diganti stub
> `routerProvider` di bagian bawah agar berkas bisa dianalisis. Selain itu
> isinya identik dengan draf asli.

```dart
// ⚠️ FILE SEMENTARA: draf AI Challenge yang belum diperbaiki.
// Dipakai hanya untuk membuktikan error kompilasinya, lalu dihapus.
// Isi identik dengan draf subagent, kecuali baris import router (disesuaikan
// agar bisa dianalisis di project ini) dan stub routerProvider di bagian bawah.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui' show DartPluginRegistrant;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

// ───────────────────────────── Konstanta ─────────────────────────────

const String kAnnouncementTopic = 'pengumuman-kampus';
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.kampus.ac.id',
);

final AndroidNotificationChannel kCampusChannel = AndroidNotificationChannel(
  'campus_announcement_channel',
  'Pengumuman Kampus',
  description: 'Pengumuman akademik dan informasi kampus',
  importance: Importance.max,
  playSound: true,
);

const AndroidInitializationSettings _androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

const DarwinInitializationSettings _darwinInit = DarwinInitializationSettings(
  requestAlertPermission: false,
  requestBadgePermission: false,
  requestSoundPermission: false,
);

const InitializationSettings _initSettings =
    InitializationSettings(android: _androidInit, iOS: _darwinInit);

// ─────────────── Background handler (WAJIB top-level) ───────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();

  final local = FlutterLocalNotificationsPlugin();
  await _initLocalIsolate(local);
  await showCampusNotification(local, message);
}

Future<void> _initLocalIsolate(FlutterLocalNotificationsPlugin plugin) async {
  await plugin.initialize(_initSettings);
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(kCampusChannel);
}

@pragma('vm:entry-point')
void onBackgroundNotificationTap(NotificationResponse response) {
  dev.log('[push] background tap payload=${response.payload}');
}

Future<void> showCampusNotification(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message,
) async {
  final data = message.data;
  final title = message.notification?.title ??
      data['title'] as String? ??
      'Pengumuman Kampus';
  final body = message.notification?.body ?? data['body'] as String? ?? '';
  if (title.isEmpty && body.isEmpty) return;

  final payload = jsonEncode({
    'route': data['route'],
    'data': data,
  });

  final androidDetails = AndroidNotificationDetails(
    kCampusChannel.id,
    kCampusChannel.name,
    channelDescription: kCampusChannel.description,
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    styleInformation: BigTextStyleInformation(body, contentTitle: title),
    category: AndroidNotificationCategory.message,
  );

  const darwinDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.active,
  );

  await plugin.show(
    message.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff),
    title,
    body,
    NotificationDetails(android: androidDetails, iOS: darwinDetails),
    payload: payload,
  );
}

// ───────────────────────────── PushService ─────────────────────────────

class PushService {
  PushService(this._ref);

  final Ref _ref;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _kToken = 'fcm_token';
  static const String _kDeviceId = 'device_id';
  static const String _kAuthToken = 'auth_token';

  final List<StreamSubscription<Object?>> _subs =
      <StreamSubscription<Object?>>[];

  bool _initialized = false;
  bool _routerReady = false;
  String? _pendingRoute;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _initLocalNotifications();
    final granted = await requestPermission();
    dev.log('[push] permission granted=$granted');

    await _configureForegroundPresentation();
    await _syncToken();
    _bindStreams();
    await subscribeToAnnouncements();
    await _consumeInitialMessage();
  }

  Future<void> _initLocalNotifications() async {
    await _local.initialize(
      _initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationTap,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(kCampusChannel);
  }

  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ok = await androidPlugin?.requestNotificationsPermission();
      return ok ??
          (settings.authorizationStatus == AuthorizationStatus.authorized);
    }

    if (!kIsWeb && Platform.isIOS) {
      final iosPlugin = _local.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final ok = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return ok ??
          (settings.authorizationStatus == AuthorizationStatus.authorized);
    }

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _configureForegroundPresentation() async {
    if (kIsWeb || !Platform.isIOS) return;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
  }

  Future<String?> getToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      try {
        await _messaging.deleteToken();
      } on FirebaseMessagingException catch (e) {
        dev.log('[push] deleteToken gagal: ${e.code}');
      }
    }

    await _waitForApnsToken();

    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _storage.write(key: _kToken, value: token);
      }
      return token;
    } on FirebaseMessagingException catch (e) {
      dev.log('[push] getToken gagal: ${e.code} ${e.message}');
      return _storage.read(key: _kToken);
    }
  }

  Future<void> _waitForApnsToken({int attempts = 6}) async {
    if (kIsWeb || !Platform.isIOS) return;

    for (var i = 0; i < attempts; i++) {
      final apns = await _messaging.getAPNSToken();
      if (apns != null && apns.isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    dev.log('[push] APNs token belum tersedia setelah ${attempts}x percobaan');
  }

  Future<void> _syncToken({bool forceRefresh = false}) async {
    final token = await getToken(forceRefresh: forceRefresh);
    if (token == null || token.isEmpty) return;
    await _registerDevice(token);
  }

  void _bindStreams() {
    _subs.add(_messaging.onTokenRefresh.listen(_handleTokenRefresh));
    _subs.add(FirebaseMessaging.onMessage.listen(_handleForegroundMessage));
    _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedApp));
  }

  Future<void> _handleTokenRefresh(String token) async {
    await _storage.write(key: _kToken, value: token);
    await _registerDevice(token);
  }

  Future<void> _registerDevice(String token) async {
    final auth = await _storage.read(key: _kAuthToken);
    final deviceId = await _resolveDeviceId();

    try {
      final res = await http
          .post(
            Uri.parse('$kApiBaseUrl/devices'),
            headers: {
              'Content-Type': 'application/json',
              if (auth != null) 'Authorization': 'Bearer $auth',
            },
            body: jsonEncode({
              'device_id': deviceId,
              'fcm_token': token,
              'platform': kIsWeb ? 'web' : Platform.operatingSystem,
              'topics': [kAnnouncementTopic],
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        dev.log('[push] POST /devices -> ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      dev.log('[push] POST /devices error: $e');
    }
  }

  Future<String> _resolveDeviceId() async {
    final cached = await _storage.read(key: _kDeviceId);
    if (cached != null && cached.isNotEmpty) return cached;

    final rnd = Random.secure();
    final id = List.generate(
      16,
      (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _storage.write(key: _kDeviceId, value: id);
    return id;
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await showCampusNotification(_local, message);
  }

  void _handleOpenedApp(RemoteMessage message) {
    _navigate(_routeOf(message));
  }

  Future<void> _consumeInitialMessage() async {
    final initial = await _messaging.getInitialMessage();
    if (initial == null) return;
    _navigate(_routeOf(initial));
  }

  String? _routeOf(RemoteMessage message) {
    final route = message.data['route'];
    return _sanitizeRoute(route is String ? route : null);
  }

  String? _sanitizeRoute(String? route) {
    if (route == null || route.isEmpty) return null;
    if (!route.startsWith('/') || route.startsWith('//')) return null;
    return route;
  }

  void _navigate(String? route) {
    if (route == null) return;

    if (!_routerReady) {
      _pendingRoute = route;
      return;
    }

    final router = _ref.read(routerProvider);
    router.go(route);
  }

  void onRouterReady() {
    _routerReady = true;
    final pending = _pendingRoute;
    _pendingRoute = null;
    if (pending != null) _navigate(pending);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    _navigate(_routeFromPayload(response.payload));
  }

  String? _routeFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final route = map['route'];
      return _sanitizeRoute(route is String ? route : null);
    } catch (_) {
      return null;
    }
  }

  Future<void> subscribeToAnnouncements() =>
      _setTopic(kAnnouncementTopic, subscribe: true);

  Future<void> unsubscribeFromAnnouncements() =>
      _setTopic(kAnnouncementTopic, subscribe: false);

  Future<void> _setTopic(String topic, {required bool subscribe}) async {
    try {
      await _waitForApnsToken();

      if (subscribe) {
        await _messaging.subscribeToTopic(topic);
      } else {
        await _messaging.unsubscribeFromTopic(topic);
      }

      await _storage.write(
        key: 'topic_$topic',
        value: subscribe ? '1' : '0',
      );
    } on FirebaseMessagingException catch (e) {
      dev.log('[push] topic $topic gagal: ${e.code} ${e.message}');
    }
  }

  Future<void> unregister() async {
    await unsubscribeFromAnnouncements();
    try {
      await _messaging.deleteToken();
    } on FirebaseMessagingException catch (e) {
      dev.log('[push] deleteToken gagal: ${e.code}');
    }
    await _storage.delete(key: _kToken);
  }

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

// Stub minimal agar berkas ini bisa dianalisis tanpa router asli.
final Provider<GoRouter> routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(routes: <RouteBase>[]),
);
```
