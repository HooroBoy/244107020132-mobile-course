import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/app_notification.dart';
import '../../../domain/entities/push_registration.dart';
import '../../../domain/routes.dart';
import '../app_router.dart';
import '../dependencies.dart';
import '../notifications/notification_controller.dart';
import 'push_state.dart';

final NotifierProvider<PushController, PushState> pushProvider =
    NotifierProvider<PushController, PushState>(PushController.new);

/// Menyatukan FCM dengan state UI.
///
/// Controller ini sengaja tipis: pemasangan FCM ada di `StartPushUseCase`,
/// pencatatan notifikasi di `AddNotificationUseCase`, dan navigasi di sini
/// karena hanya presentation yang boleh menyentuh router.
class PushController extends Notifier<PushState> {
  /// Pemasangan FCM yang sedang aktif; pemegang langganan stream.
  PushRegistration? _registration;

  @override
  PushState build() {
    ref.onDispose(() => _registration?.stop());
    return const PushState();
  }

  /// Dipanggil sekali setelah frame pertama, dan lagi setiap kali pengguna
  /// login. `started` membuat pemanggilan berulang aman.
  Future<void> start({required bool firebaseReady, String? firebaseNote}) async {
    if (state.started) return;

    if (!firebaseReady) {
      state = PushState(
        note: firebaseNote ?? 'Firebase belum dikonfigurasi.',
      );
      return;
    }

    state = const PushState(started: true);

    try {
      final PushRegistration registration =
          await ref.read(startPushUseCaseProvider)(
        onRoute: _go,
        onNotification: _record,
        onOpened: _openFromNotification,
      );

      _registration = registration;
      state = state.copyWith(
        token: registration.token,
        permissionGranted: registration.permissionGranted,
        registeredOnBackend: registration.registeredOnBackend,
        subscribedTopic: true,
        note: _noteFor(registration),
      );
    } on Object catch (error) {
      // Hanya jenis error yang dicatat, bukan isi pesan atau token.
      state = state.copyWith(
        note: 'FCM gagal disiapkan: ${error.runtimeType}',
      );
    }
  }

  /// Catatan yang layak dibaca pengguna, diturunkan dari hasil use case.
  String? _noteFor(PushRegistration registration) {
    if (!registration.permissionGranted) {
      return 'Izin notifikasi ditolak. Aktifkan lewat pengaturan aplikasi.';
    }
    if (!registration.registeredOnBackend) {
      return 'Token siap di perangkat. Endpoint POST /devices belum tersedia '
          '(base URL masih demo).';
    }
    return null;
  }

  void _go(String route) {
    final String safe = Routes.sanitize(route);
    state = state.copyWith(lastRoute: safe);
    ref.read(appRouterProvider).go(safe);
  }

  /// Mencatat notifikasi yang masuk ke kotak masuk (status belum dibaca).
  Future<void> _record(AppNotification notification) =>
      ref.read(notificationsProvider.notifier).add(notification);

  /// Dipanggil ketika pengguna mengetuk notifikasi dari panel sistem.
  ///
  /// Entri dengan id yang sama dihapus karena pengguna sudah membacanya di panel
  /// notifikasi, lalu aplikasi menavigasi ke rute dari payload.
  Future<void> _openFromNotification(String? messageId, String route) async {
    final String id = messageId?.trim() ?? '';
    if (id.isNotEmpty) {
      await ref.read(notificationsProvider.notifier).markRead(id);
    }
    _go(route);
  }

  /// Melepas listener dan langganan topik saat logout.
  ///
  /// Perangkat dilepas dari backend oleh `LogoutUseCase` (butuh access token
  /// yang masih berlaku), jadi di sini cukup menghentikan pemasangan FCM.
  /// `started` dikembalikan ke `false` supaya `start()` bisa memasang ulang FCM
  /// ketika pengguna login lagi tanpa menutup aplikasi.
  Future<void> detach() async {
    final PushRegistration? registration = _registration;
    _registration = null;
    await registration?.stop();

    state = state.copyWith(
      started: false,
      token: null,
      registeredOnBackend: false,
      subscribedTopic: false,
      lastRoute: null,
      note: null,
    );
  }

  /// Notifikasi uji lokal: membuktikan banner foreground, suara kustom, kotak
  /// masuk, dan badge tanpa menunggu pengiriman dari Firebase Console.
  Future<void> sendTestNotification() =>
      ref.read(sendTestNotificationUseCaseProvider)();

  Future<void> toggleTopic(bool subscribe) async {
    await ref.read(setTopicSubscriptionUseCaseProvider)(subscribe: subscribe);
    state = state.copyWith(subscribedTopic: subscribe);
  }
}
