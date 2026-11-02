import '../../entities/app_notification.dart';
import '../../entities/notification_inbox.dart';
import '../../repositories/notification_inbox_repository.dart';
import 'sync_badge_usecase.dart';

/// Menandai satu notifikasi sudah dibaca: entri hilang dari daftar.
class MarkNotificationReadUseCase {
  const MarkNotificationReadUseCase(this._inbox, this._syncBadge);

  final NotificationInboxRepository _inbox;
  final SyncBadgeUseCase _syncBadge;

  Future<List<AppNotification>> call(String id) async {
    final List<AppNotification> current = await _inbox.readAll();
    final List<AppNotification> next = NotificationInbox.without(current, id);

    await _inbox.writeAll(next);
    await _syncBadge(next.length);
    return next;
  }
}
