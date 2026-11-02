import 'dart:convert';

import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_inbox_repository.dart';
import '../datasources/key_value_store.dart';
import '../mappers/app_notification_mapper.dart';

/// Kotak masuk notifikasi di `shared_preferences`.
///
/// Isinya pengumuman, bukan kredensial, jadi penyimpanan biasa sudah cukup —
/// token tetap hanya di secure storage. Kelas ini hanya menyimpan apa adanya;
/// aturan dedupe dan batas jumlah ada di `NotificationInbox` (domain).
class SharedPrefsInboxRepository implements NotificationInboxRepository {
  SharedPrefsInboxRepository({KeyValueStore? store})
      : _store = store ?? PrefsKeyValueStore();

  final KeyValueStore _store;

  /// Kunci penyimpanan. Handler background memakai kunci yang sama.
  static const String storageKey = 'campus_notif.inbox';

  @override
  Future<List<AppNotification>> readAll() async {
    final String? raw = await _store.read(storageKey);
    if (raw == null || raw.isEmpty) return <AppNotification>[];

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <AppNotification>[];

      final List<AppNotification> items = <AppNotification>[];
      for (final Object? entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final AppNotification? item = appNotificationFromJson(entry);
          if (item != null) items.add(item);
        }
      }
      return items;
    } on FormatException {
      // Data rusak: mulai dari kotak masuk kosong, jangan crash.
      return <AppNotification>[];
    }
  }

  @override
  Future<void> writeAll(List<AppNotification> items) async {
    final String raw = jsonEncode(
      items.map(appNotificationToJson).toList(),
    );
    await _store.write(storageKey, raw);
  }
}
