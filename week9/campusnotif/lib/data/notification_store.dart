import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Satu pengumuman yang diterima aplikasi lewat notifikasi.
///
/// Disimpan di penyimpanan biasa (bukan secure storage) karena isinya bukan
/// rahasia — berbeda dengan token yang wajib di `flutter_secure_storage`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    required this.receivedAt,
  });

  /// Membuat entri dari payload FCM atau banner lokal.
  ///
  /// `messageId` dipakai sebagai id bila tersedia, supaya pesan yang sama tidak
  /// tercatat dua kali ketika FCM mengirim ulang.
  factory AppNotification.fromMessage({
    String? messageId,
    required String title,
    required String body,
    required String route,
    DateTime? receivedAt,
  }) {
    final DateTime at = receivedAt ?? DateTime.now();
    final String trimmedId = messageId?.trim() ?? '';
    return AppNotification(
      id: trimmedId.isEmpty ? '${at.microsecondsSinceEpoch}-$route' : trimmedId,
      title: title.trim().isEmpty ? 'Pengumuman' : title.trim(),
      body: body.trim(),
      route: route,
      receivedAt: at,
    );
  }

  final String id;
  final String title;
  final String body;

  /// Rute deep link yang dibuka saat notifikasi diketuk.
  final String route;
  final DateTime receivedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'route': route,
        'received_at': receivedAt.toIso8601String(),
      };

  /// Mengembalikan `null` untuk data rusak, bukan melempar exception.
  ///
  /// Satu entri yang korup tidak boleh membuat seluruh kotak masuk hilang.
  static AppNotification? fromJson(Map<String, dynamic> json) {
    final Object? id = json['id'];
    final Object? route = json['route'];
    if (id is! String || id.isEmpty || route is! String || route.isEmpty) {
      return null;
    }

    final Object? title = json['title'];
    final Object? body = json['body'];
    final Object? receivedAt = json['received_at'];

    return AppNotification(
      id: id,
      title: title is String && title.isNotEmpty ? title : 'Pengumuman',
      body: body is String ? body : '',
      route: route,
      receivedAt: DateTime.tryParse('$receivedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Abstraksi penyimpanan kunci-nilai sederhana.
///
/// Dipisah dari `shared_preferences` agar test bisa memakai memori biasa dan
/// tidak menyentuh platform channel.
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Implementasi nyata di atas `shared_preferences`.
class PrefsKeyValueStore implements KeyValueStore {
  PrefsKeyValueStore({SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
}

/// Penyimpanan di memori, dipakai test.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? initial])
      : values = <String, String>{...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// Kotak masuk notifikasi yang bertahan setelah aplikasi ditutup.
///
/// Hanya berisi notifikasi yang **belum dibaca**. Begitu dibaca, entri dihapus
/// dari daftar — sesuai perilaku yang diminta: notifikasi yang dibaca hilang.
class NotificationStore {
  NotificationStore(this._store);

  final KeyValueStore _store;

  /// Kunci penyimpanan. Handler background memakai kunci yang sama.
  static const String storageKey = 'campus_notif.inbox';

  /// Batas jumlah entri agar daftar tidak tumbuh tanpa kendali.
  static const int maxEntries = 50;

  Future<List<AppNotification>> load() async {
    final String? raw = await _store.read(storageKey);
    if (raw == null || raw.isEmpty) return <AppNotification>[];

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <AppNotification>[];

      final List<AppNotification> items = <AppNotification>[];
      for (final Object? entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final AppNotification? item = AppNotification.fromJson(entry);
          if (item != null) items.add(item);
        }
      }
      return items;
    } on FormatException {
      // Data rusak: mulai dari kotak masuk kosong, jangan crash.
      return <AppNotification>[];
    }
  }

  /// Menambahkan [notification] di urutan teratas lalu menyimpan.
  ///
  /// Entri dengan id yang sama diganti, bukan diduplikasi.
  Future<List<AppNotification>> append(AppNotification notification) async {
    final List<AppNotification> current = await load();
    final List<AppNotification> next = <AppNotification>[
      notification,
      ...current.where((AppNotification item) => item.id != notification.id),
    ];

    if (next.length > maxEntries) next.removeRange(maxEntries, next.length);
    await _save(next);
    return next;
  }

  /// Menghapus satu entri — dipakai saat notifikasi dibaca.
  Future<List<AppNotification>> remove(String id) async {
    final List<AppNotification> current = await load();
    final List<AppNotification> next =
        current.where((AppNotification item) => item.id != id).toList();
    await _save(next);
    return next;
  }

  /// Mengosongkan seluruh kotak masuk.
  Future<List<AppNotification>> clear() async {
    await _save(<AppNotification>[]);
    return <AppNotification>[];
  }

  Future<void> _save(List<AppNotification> items) async {
    final String raw = jsonEncode(
      items.map((AppNotification item) => item.toJson()).toList(),
    );
    await _store.write(storageKey, raw);
  }
}
