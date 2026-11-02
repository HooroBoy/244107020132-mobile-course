import '../entities/app_notification.dart';

/// Kemampuan push notification yang dibutuhkan lapisan atas.
///
/// Sengaja memakai istilah domain ([AppNotification], `String` token), bukan tipe
/// plugin, sehingga presentation tidak pernah meng-import `firebase_messaging`.
/// Inilah Dependency Inversion pada titik yang paling rawan: pesan datang dari
/// luar proses aplikasi.
abstract interface class PushMessaging {
  /// Menyiapkan kanal notifikasi dan handler banner.
  ///
  /// Wajib dipanggil sebelum pesan pertama datang: setelan kanal Android tidak
  /// bisa diubah setelah kanal dibuat, jadi kanal dengan suara kustom harus
  /// dibuat lebih dulu oleh aplikasi.
  Future<void> prepare();

  /// Meminta izin notifikasi. Android 13+ dan iOS memerlukannya saat runtime.
  Future<bool> requestPermission();

  /// Token perangkat saat ini, atau `null` bila Firebase belum memberikannya.
  Future<String?> currentToken();

  /// Token berubah (reinstall / clear data). Wajib dilaporkan ulang ke backend,
  /// kalau tidak backend menyimpan token basi dan notifikasi berhenti sampai.
  Stream<String> get tokenRefresh;

  /// Pesan yang masuk saat aplikasi foreground.
  ///
  /// Sistem tidak menampilkan banner pada kondisi ini; pemakai wajib memanggil
  /// [showBanner] sendiri.
  Stream<AppNotification> get foregroundMessages;

  /// Pesan yang diketuk pengguna dari panel sistem (background / terminated).
  Stream<AppNotification> get openedMessages;

  /// Ketukan pada banner lokal (kasus foreground). Hanya membawa rute karena
  /// banner lokal tidak menyimpan metadata pesan.
  Stream<String> get bannerTaps;

  /// Pesan yang membuka aplikasi dari state terminated.
  ///
  /// Dikonsumsi sekali per proses, supaya deep link tidak terbuka dua kali.
  Future<AppNotification?> initialMessage();

  Future<void> subscribeTopic(String topic);

  Future<void> unsubscribeTopic(String topic);

  /// Menampilkan banner lokal dengan suara kustom.
  Future<void> showBanner(AppNotification notification);
}
