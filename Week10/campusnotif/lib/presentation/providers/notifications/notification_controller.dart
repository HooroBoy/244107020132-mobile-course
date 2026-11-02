import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/app_notification.dart';
import '../dependencies.dart';

/// Kotak masuk notifikasi yang belum dibaca.
///
/// Panjang daftar = jumlah notifikasi belum dibaca, sekaligus angka yang
/// ditampilkan pada badge ikon aplikasi. Controller ini hanya memegang state;
/// aturan dedupe/batas dan sinkronisasi badge dijalankan use case.
final NotifierProvider<NotificationController, List<AppNotification>>
    notificationsProvider =
    NotifierProvider<NotificationController, List<AppNotification>>(
  NotificationController.new,
);

class NotificationController extends Notifier<List<AppNotification>> {
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
  /// Dipakai saat aplikasi dibuka dan saat kembali aktif, karena handler
  /// background bisa menulis entri baru ketika aplikasi tidak berjalan.
  Future<void> reload() async {
    try {
      final List<AppNotification> items =
          await ref.read(loadInboxUseCaseProvider)();
      if (_disposed) return;
      state = items;
    } on Object {
      // Penyimpanan belum siap: biarkan kotak masuk kosong.
    }
  }

  /// Mencatat notifikasi baru sebagai belum dibaca.
  Future<void> add(AppNotification notification) async {
    try {
      final List<AppNotification> next =
          await ref.read(addNotificationUseCaseProvider)(notification);
      if (_disposed) return;
      state = next;
    } on Object {
      // Gagal menyimpan tidak boleh menghalangi notifikasi tampil.
    }
  }

  /// Menandai satu notifikasi sudah dibaca: entri hilang dari daftar.
  Future<void> markRead(String id) async {
    try {
      final List<AppNotification> next =
          await ref.read(markNotificationReadUseCaseProvider)(id);
      if (_disposed) return;
      state = next;
    } on Object {
      // Abaikan; daftar tetap seperti sebelumnya.
    }
  }

  /// Menandai semua notifikasi sudah dibaca.
  Future<void> markAllRead() async {
    try {
      final List<AppNotification> next =
          await ref.read(markAllNotificationsReadUseCaseProvider)();
      if (_disposed) return;
      state = next;
    } on Object {
      // Abaikan.
    }
  }
}
