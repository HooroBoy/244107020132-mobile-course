import '../../entities/app_notification.dart';
import '../../repositories/notification_inbox_repository.dart';
import 'sync_badge_usecase.dart';

/// Membaca ulang kotak masuk lalu menyelaraskan badge.
///
/// Dipakai saat aplikasi dibuka dan saat aplikasi kembali aktif, karena handler
/// background menulis ke penyimpanan dari isolate lain sehingga daftar di
/// memori bisa tertinggal.
class LoadInboxUseCase {
  const LoadInboxUseCase(this._inbox, this._syncBadge);

  final NotificationInboxRepository _inbox;
  final SyncBadgeUseCase _syncBadge;

  Future<List<AppNotification>> call() async {
    final List<AppNotification> items = await _inbox.readAll();
    await _syncBadge(items.length);
    return items;
  }
}
