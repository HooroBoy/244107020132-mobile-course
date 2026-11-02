import '../entities/app_notification.dart';

/// Penyimpanan kotak masuk notifikasi yang bertahan setelah aplikasi ditutup.
///
/// Sengaja hanya "baca semua / tulis semua": aturan dedupe dan batas jumlah
/// adalah keputusan bisnis di [NotificationInbox], bukan urusan penyimpanan.
abstract interface class NotificationInboxRepository {
  /// Entri tersimpan. Data rusak diabaikan, bukan melempar exception.
  Future<List<AppNotification>> readAll();

  Future<void> writeAll(List<AppNotification> items);
}
