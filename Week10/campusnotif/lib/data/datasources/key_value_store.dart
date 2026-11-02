import 'package:shared_preferences/shared_preferences.dart';

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
