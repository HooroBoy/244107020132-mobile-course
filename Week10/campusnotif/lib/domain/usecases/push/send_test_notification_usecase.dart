import '../../entities/app_notification.dart';
import '../../repositories/push_messaging.dart';
import '../../routes.dart';
import '../notifications/add_notification_usecase.dart';

/// Notifikasi uji lokal: membuktikan banner foreground, suara kustom, kotak
/// masuk, dan badge tanpa menunggu pengiriman dari Firebase Console.
class SendTestNotificationUseCase {
  const SendTestNotificationUseCase(this._push, this._addNotification);

  final PushMessaging _push;
  final AddNotificationUseCase _addNotification;

  Future<void> call() async {
    final AppNotification notification = AppNotification.create(
      title: 'Jadwal kuliah berubah',
      body: 'Kelas Mobile pindah ke Ruang A2 jam 13.00',
      route: Routes.announcement('3'),
    );

    await _addNotification(notification);
    await _push.showBanner(notification);
  }
}
