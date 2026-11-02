import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/badge_service.dart';
import '../data/notification_store.dart';

/// Penyimpanan kunci-nilai. Di-override di test dengan
/// [InMemoryKeyValueStore] agar tidak menyentuh platform channel.
final Provider<KeyValueStore> keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => PrefsKeyValueStore(),
);

final Provider<NotificationStore> notificationStoreProvider =
    Provider<NotificationStore>(
  (ref) => NotificationStore(ref.watch(keyValueStoreProvider)),
);

final Provider<BadgeService> badgeServiceProvider = Provider<BadgeService>(
  (ref) => const BadgeService(),
);

/// Kotak masuk notifikasi yang belum dibaca.
///
/// Panjang daftar = jumlah notifikasi belum dibaca, sekaligus angka yang
/// ditampilkan pada badge ikon aplikasi.
final NotifierProvider<NotificationCenter, List<AppNotification>>
    notificationsProvider =
    NotifierProvider<NotificationCenter, List<AppNotification>>(
  NotificationCenter.new,
);

class NotificationCenter extends Notifier<List<AppNotification>> {
  bool _disposed = false;

  @override
  List<AppNotification> build() {
    ref.onDispose(() => _disposed = true);
    // Muat isi penyimpanan setelah build selesai, supaya `state` bisa diubah
    // tanpa melanggar siklus build Riverpod.
    Future<void>.microtask(reload);
    return const <AppNotification>[];
  }

  /// Jumlah notifikasi yang belum dibaca.
  int get unreadCount => state.length;

  /// Membaca ulang dari penyimpanan.
  ///
  /// Dipakai saat aplikasi dibuka, karena handler background bisa menulis
  /// entri baru ketika aplikasi tidak berjalan.
  Future<void> reload() async {
    try {
      final List<AppNotification> items =
          await ref.read(notificationStoreProvider).load();
      if (_disposed) return;
      state = items;
      await _syncBadge();
    } on Object {
      // Penyimpanan belum siap: biarkan kotak masuk kosong.
    }
  }

  /// Mencatat notifikasi baru sebagai belum dibaca.
  Future<void> add(AppNotification notification) async {
    try {
      final List<AppNotification> next =
          await ref.read(notificationStoreProvider).append(notification);
      if (_disposed) return;
      state = next;
      await _syncBadge();
    } on Object {
      // Gagal menyimpan tidak boleh menghalangi notifikasi tampil.
    }
  }

  /// Menandai satu notifikasi sudah dibaca: entri hilang dari daftar.
  Future<void> markRead(String id) async {
    try {
      final List<AppNotification> next =
          await ref.read(notificationStoreProvider).remove(id);
      if (_disposed) return;
      state = next;
      await _syncBadge();
    } on Object {
      // Abaikan; daftar tetap seperti sebelumnya.
    }
  }

  /// Menandai semua notifikasi sudah dibaca.
  Future<void> markAllRead() async {
    try {
      final List<AppNotification> next =
          await ref.read(notificationStoreProvider).clear();
      if (_disposed) return;
      state = next;
      await _syncBadge();
    } on Object {
      // Abaikan.
    }
  }

  Future<void> _syncBadge() async {
    try {
      await ref.read(badgeServiceProvider).setCount(state.length);
    } on Object {
      // Badge bersifat tambahan; kegagalannya tidak boleh terlihat pengguna.
    }
  }
}
