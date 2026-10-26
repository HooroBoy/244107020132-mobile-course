import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_repository.dart';
import '../data/masking.dart';
import '../messaging/push_service.dart';
import '../routes.dart';
import 'app_router.dart';
import 'auth_provider.dart';

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

    await _service.listenMessages(onRoute: _go);

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

  /// Notifikasi uji lokal: membuktikan banner foreground + deep link tanpa
  /// menunggu pengiriman dari Firebase Console.
  Future<void> sendTestNotification() async {
    await _service.showLocalNotification(
      title: 'Jadwal kuliah berubah',
      body: 'Kelas Mobile pindah ke Ruang A2 jam 13.00',
      route: Routes.announcement('3'),
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
