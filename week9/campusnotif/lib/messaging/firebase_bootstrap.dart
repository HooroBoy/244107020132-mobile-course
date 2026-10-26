import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handler pesan saat aplikasi di background/terminated.
///
/// WAJIB berupa fungsi top-level (bukan method kelas) karena dijalankan pada
/// isolate terpisah. Di sini tidak boleh menyentuh `BuildContext`, Riverpod,
/// router, atau state UI apa pun. Tugasnya hanya mencatat ringan; navigasi
/// dilakukan saat pengguna mengetuk notifikasi.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Isolate ini punya instance Firebase sendiri.
  await Firebase.initializeApp();
  // Hanya id pesan yang dicatat. Token dan isi payload tidak pernah di-log.
  debugPrint('[FCM] background message ${message.messageId ?? '-'}');
}

/// Hasil inisialisasi Firebase, dipakai UI untuk menampilkan status apa adanya.
class FirebaseBootstrap {
  const FirebaseBootstrap({required this.ready, this.reason});

  const FirebaseBootstrap.notConfigured(String this.reason) : ready = false;

  final bool ready;

  /// Alasan teknis bila [ready] bernilai `false`.
  final String? reason;
}

/// Menginisialisasi Firebase tanpa membuat aplikasi gagal total.
///
/// Bila `android/app/google-services.json` belum ada (atau platform tidak
/// didukung), Firebase melempar exception. Aplikasi tetap harus bisa dipakai
/// untuk login dan navigasi, jadi kegagalan di sini ditangkap dan dilaporkan
/// sebagai status, bukan crash.
Future<FirebaseBootstrap> bootstrapFirebase() async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    return const FirebaseBootstrap(ready: true);
  } on Object catch (error) {
    final String message = error.toString();
    final bool looksLikeMissingConfig = message.contains('google-services') ||
        message.contains('FirebaseOptions') ||
        message.contains('not been correctly initialized') ||
        message.contains('core/no-app');

    return FirebaseBootstrap.notConfigured(
      looksLikeMissingConfig
          ? 'Firebase belum dikonfigurasi: letakkan google-services.json '
              'di android/app/ lalu build ulang.'
          : 'Firebase gagal diinisialisasi: $message',
    );
  }
}
