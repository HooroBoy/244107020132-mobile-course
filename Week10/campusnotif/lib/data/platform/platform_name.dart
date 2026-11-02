import 'package:flutter/foundation.dart';

/// Nama platform untuk laporan `POST /devices`.
///
/// Deteksi platform adalah kemampuan lapisan data. Domain cukup meminta
/// "daftarkan token ini" tanpa ikut tahu API Flutter.
String get platformName {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform.name;
}
