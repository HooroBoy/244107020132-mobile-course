import 'app_notification.dart';

/// Aturan kotak masuk notifikasi.
///
/// Kotak masuk hanya berisi notifikasi yang **belum dibaca**, tanpa duplikat,
/// dan dibatasi [maxEntries]. Aturannya berupa fungsi murni di lapisan domain
/// supaya bisa diuji tanpa penyimpanan maupun widget — implementasi penyimpanan
/// di lapisan data hanya menulis apa yang diputuskan di sini.
abstract final class NotificationInbox {
  /// Batas jumlah entri agar daftar tidak tumbuh tanpa kendali.
  static const int maxEntries = 50;

  /// Menambahkan [item] di urutan teratas.
  ///
  /// Entri dengan id yang sama diganti, bukan diduplikasi.
  static List<AppNotification> withAdded(
    List<AppNotification> current,
    AppNotification item,
  ) {
    final List<AppNotification> next = <AppNotification>[
      item,
      ...current.where((AppNotification existing) => existing.id != item.id),
    ];

    if (next.length > maxEntries) next.removeRange(maxEntries, next.length);
    return next;
  }

  /// Menghapus satu entri — dipakai saat notifikasi dibaca.
  static List<AppNotification> without(
    List<AppNotification> current,
    String id,
  ) {
    return current
        .where((AppNotification item) => item.id != id)
        .toList(growable: false);
  }
}
