import '../../entities/app_notification.dart';
import '../../entities/notification_inbox.dart';
import '../../repositories/notification_inbox_repository.dart';
import 'sync_badge_usecase.dart';

/// Mencatat notifikasi baru sebagai belum dibaca.
///
/// Aturan dedupe dan batas [NotificationInbox.maxEntries] dijalankan di sini,
/// bukan di penyimpanan, sehingga tetap berlaku untuk penyimpanan apa pun.
class AddNotificationUseCase {
  const AddNotificationUseCase(this._inbox, this._syncBadge);

  final NotificationInboxRepository _inbox;
  final SyncBadgeUseCase _syncBadge;

  Future<List<AppNotification>> call(AppNotification notification) async {
    final List<AppNotification> current = await _inbox.readAll();
    final List<AppNotification> next =
        NotificationInbox.withAdded(current, notification);

    await _inbox.writeAll(next);
    await _syncBadge(next.length);
    return next;
  }
}
