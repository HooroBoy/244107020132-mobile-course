import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_repository.dart';
import '../data/masking.dart';
import '../data/notification_store.dart';
import '../messaging/push_service.dart';
import '../routes.dart';
import 'app_router.dart';
import 'auth_provider.dart';
import 'notification_providers.dart';

final Provider<PushService> pushServiceProvider = Provider<PushService>(
  (ref) => PushService(),
);

final Provider<DeviceRepository> deviceRepositoryProvider =
    Provider<DeviceRepository>(
  (ref) => DeviceRepository(ref.watch(apiClientProvider)),
);

/// Status FCM yang ditampilkan di UI sebagai bukti pengujian.
class PushState {
  const PushState({
    this.started = false,
    this.permissionGranted = false,
    this.token,
    this.registeredOnBackend = false,
    this.subscribedTopic = false,
    this.lastRoute,
    this.note,
  });

  final bool started;
  final bool permissionGranted;

  /// Token utuh; hanya dipakai internal. UI memakai [maskedToken].
  final String? token;
  final bool registeredOnBackend;
  final bool subscribedTopic;
  final String? lastRoute;
  final String? note;

  /// Token terpotong untuk ditampilkan / difoto.
  String get maskedToken => token == null ? '-' : maskSecret(token!);

  PushState copyWith({
    bool? started,
    bool? permissionGranted,
    String? token,
    bool? registeredOnBackend,
    bool? subscribedTopic,
    String? lastRoute,
    String? note,
  }) {
    return PushState(
      started: started ?? this.started,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      token: token ?? this.token,
      registeredOnBackend: registeredOnBackend ?? this.registeredOnBackend,
      subscribedTopic: subscribedTopic ?? this.subscribedTopic,
      lastRoute: lastRoute ?? this.lastRoute,
      note: note ?? this.note,
    );
  }
}

final NotifierProvider<PushController, PushState> pushProvider =
    NotifierProvider<PushController, PushState>(PushController.new);

/// Menyatukan FCM, local notification, backend device, dan router.
///
/// Inisialisasi dipanggil sekali setelah frame pertama, saat router sudah siap
/// menerima navigasi dari `getInitialMessage`.
class PushController extends Notifier<PushState> {
  @override
  PushState build() => const PushState();

  PushService get _service => ref.read(pushServiceProvider);

  Future<void> start({required bool firebaseReady, String? firebaseNote}) async {
    if (state.started) return;

    if (!firebaseReady) {
      state = PushState(
        note: firebaseNote ?? 'Firebase belum dikonfigurasi.',
      );
      return;
    }

    state = const PushState(started: true);

    await _service.initLocalNotifications();

    final bool granted = await _service.requestPermission();
    state = state.copyWith(permissionGranted: granted);

    if (!granted) {
      state = state.copyWith(
        note: 'Izin notifikasi ditolak. Aktifkan lewat pengaturan aplikasi.',
      );
    }

    await _service.initFcmToken(onToken: _registerToken);
    await _service.subscribeCampusTopic();
    state = state.copyWith(subscribedTopic: true);

    await _service.listenMessages(
      onRoute: _go,
      onNotification: _record,
      onOpened: _openFromNotification,
    );

    // Notifikasi lokal yang diketuk sebelum handler terpasang.
    final String? pending = _service.consumePendingDeepLink();
    if (pending != null) _go(pending);
  }

  Future<void> _registerToken(String token) async {
    state = state.copyWith(token: token);

    final bool ok = await ref.read(deviceRepositoryProvider).registerDevice(
          token: token,
          platform: PushService.platformName,
        );

    state = state.copyWith(
      registeredOnBackend: ok,
      note: ok
          ? null
          : 'Token siap di perangkat. Endpoint POST /devices belum tersedia '
              '(base URL masih demo).',
    );
  }

  void _go(String route) {
    final String safe = PushService.sanitizeRoute(route);
    state = state.copyWith(lastRoute: safe);
    ref.read(appRouterProvider).go(safe);
  }

  /// Mencatat notifikasi yang masuk ke kotak masuk (status belum dibaca).
  Future<void> _record(AppNotification notification) =>
      ref.read(notificationsProvider.notifier).add(notification);

  /// Dipanggil ketika pengguna mengetuk notifikasi dari panel sistem.
  ///
  /// Entri dengan id yang sama dihapus karena pengguna sudah membacanya di
  /// panel notifikasi, lalu aplikasi menavigasi ke rute dari payload.
  Future<void> _openFromNotification(String? messageId, String route) async {
    final String id = messageId?.trim() ?? '';
    if (id.isNotEmpty) {
      await ref.read(notificationsProvider.notifier).markRead(id);
    }
    _go(route);
  }

  /// Notifikasi uji lokal: membuktikan banner foreground, suara kustom, kotak
  /// masuk, dan badge tanpa menunggu pengiriman dari Firebase Console.
  Future<void> sendTestNotification() async {
    const String title = 'Jadwal kuliah berubah';
    const String body = 'Kelas Mobile pindah ke Ruang A2 jam 13.00';
    final String route = Routes.announcement('3');

    await _record(
      AppNotification.fromMessage(title: title, body: body, route: route),
    );
    await _service.showLocalNotification(
      title: title,
      body: body,
      route: route,
    );
  }

  Future<void> toggleTopic(bool subscribe) async {
    if (subscribe) {
      await _service.subscribeCampusTopic();
    } else {
      await _service.unsubscribeCampusTopic();
    }
    state = state.copyWith(subscribedTopic: subscribe);
  }
}
