import '../../entities/app_notification.dart';
import '../../repositories/notification_inbox_repository.dart';
import 'sync_badge_usecase.dart';

/// Menandai semua notifikasi sudah dibaca: kotak masuk kosong, badge nol.
class MarkAllNotificationsReadUseCase {
  const MarkAllNotificationsReadUseCase(this._inbox, this._syncBadge);

  final NotificationInboxRepository _inbox;
  final SyncBadgeUseCase _syncBadge;

  Future<List<AppNotification>> call() async {
    await _inbox.writeAll(const <AppNotification>[]);
    await _syncBadge(0);
    return const <AppNotification>[];
  }
}
