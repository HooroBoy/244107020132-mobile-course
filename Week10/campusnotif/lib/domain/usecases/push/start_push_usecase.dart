import 'dart:async';

import '../../constants.dart';
import '../../entities/app_notification.dart';
import '../../entities/push_registration.dart';
import '../../repositories/device_repository.dart';
import '../../repositories/push_messaging.dart';

/// Memasang FCM untuk satu sesi: izin → token → lapor backend → topik →
/// listener → pesan awal.
///
/// Mengembalikan [PushRegistration] yang memegang langganan stream. Dengan
/// begitu pemasangan dan pelepasan berada di satu kelas, dan `start()` boleh
/// dipanggil lagi setelah login berikutnya tanpa menumpuk listener.
class StartPushUseCase {
  const StartPushUseCase(this._push, this._devices);

  final PushMessaging _push;
  final DeviceRepository _devices;

  Future<PushRegistration> call({
    required void Function(String route) onRoute,
    required Future<void> Function(AppNotification notification) onNotification,
    required Future<void> Function(String? messageId, String route) onOpened,
  }) async {
    // Kanal notifikasi harus siap sebelum pesan pertama datang, kalau tidak
    // Android membuat kanal sendiri dengan suara default.
    await _push.prepare();

    final bool granted = await _push.requestPermission();

    final String? token = await _push.currentToken();
    bool registered = false;
    if (token != null && token.isNotEmpty) {
      registered = await _devices.register(token: token);
    }

    await _push.subscribeTopic(kCampusTopic);

    final List<StreamSubscription<Object?>> subscriptions =
        <StreamSubscription<Object?>>[
      // Token bisa berubah setelah reinstall / clear data. Tanpa laporan ulang,
      // backend menyimpan token basi dan notifikasi berhenti sampai.
      _push.tokenRefresh.listen((String refreshed) async {
        await _devices.register(token: refreshed);
      }),
      _push.foregroundMessages.listen((AppNotification notification) async {
        await onNotification(notification);
        await _push.showBanner(notification);
      }),
      _push.openedMessages.listen((AppNotification notification) async {
        await onOpened(notification.id, notification.route);
      }),
      _push.bannerTaps.listen(onRoute),
    ];

    // Pesan yang membuka aplikasi dari state terminated.
    final AppNotification? initial = await _push.initialMessage();
    if (initial != null) {
      await onOpened(initial.id, initial.route);
    }

    return PushRegistration(
      token: token,
      permissionGranted: granted,
      registeredOnBackend: registered,
      onStop: () async {
        for (final StreamSubscription<Object?> subscription in subscriptions) {
          await subscription.cancel();
        }
        await _push.unsubscribeTopic(kCampusTopic);
      },
    );
  }
}
