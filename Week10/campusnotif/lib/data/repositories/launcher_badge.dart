import 'package:app_badge_plus/app_badge_plus.dart';

import '../../domain/repositories/app_badge.dart';

/// [AppBadge] di atas `app_badge_plus`.
///
/// Kegagalan platform channel (web, desktop, test) ditelan di sini: badge hanya
/// pelengkap, dan aplikasi tidak boleh crash karenanya.
///
/// Catatan perilaku Android: `AppBadgePlus` memakai ShortcutBadger, yang hanya
/// mengenali launcher tertentu (Samsung, MIUI, Oppo, Vivo, Huawei/Honor, Sony,
/// HTC, Asus, Nova, LG, ZTE, Yandex). Pada launcher lain — termasuk Pixel/stock
/// Android dan Infinix XOS — `isSupported()` mengembalikan `false`, sehingga
/// angka tidak bisa dipasang; launcher tersebut hanya menampilkan titik dari
/// notifikasi yang aktif (channel `pengumuman_v2` memakai `showBadge: true`).
class LauncherBadge implements AppBadge {
  const LauncherBadge();

  @override
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
