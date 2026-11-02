import 'package:app_badge_plus/app_badge_plus.dart';

/// Pembungkus badge pada ikon aplikasi.
///
/// Dibungkus supaya:
/// - kegagalan platform channel (web, desktop, test) tidak pernah membuat
///   aplikasi crash;
/// - jumlah badge punya satu tempat yang jelas untuk diuji/di-override.
///
/// Catatan perilaku Android: `AppBadgePlus` memakai ShortcutBadger, yang hanya
/// mengenali launcher tertentu (Samsung, MIUI, Oppo, Vivo, Huawei/Honor, Sony,
/// HTC, Asus, Nova, LG, ZTE, Yandex). Pada launcher lain — termasuk Pixel/stock
/// Android dan Infinix XOS — `isSupported()` mengembalikan `false`, sehingga
/// angka tidak bisa dipasang; launcher tersebut hanya menampilkan titik dari
/// notifikasi yang aktif (channel `pengumuman_v2` memakai `showBadge: true`).
///
/// Karena itu angka yang sama juga ditampilkan di dalam aplikasi (lonceng pada
/// `HomePage`), agar pengguna selalu punya rujukan yang akurat.
class BadgeService {
  const BadgeService();

  /// Menyetel jumlah badge. Nilai negatif diperlakukan sebagai 0.
  Future<void> setCount(int count) async {
    final int safeCount = count < 0 ? 0 : count;

    try {
      final bool supported = await AppBadgePlus.isSupported();
      if (!supported) return;
      await AppBadgePlus.updateBadge(safeCount);
    } on Object {
      // Tidak ada launcher/plugin yang bisa menerima badge: abaikan.
    }
  }
}
