/// Hasil pemasangan FCM untuk satu sesi.
///
/// Pemegangnya bertanggung jawab memanggil [stop] saat pengguna logout. Dengan
/// begitu siklus hidup listener dan pendaftaran perangkat punya satu pemilik
/// yang jelas, bukan tersebar di beberapa kelas.
class PushRegistration {
  PushRegistration({
    required this.token,
    required this.permissionGranted,
    required this.registeredOnBackend,
    required this.onStop,
  });

  /// Token FCM perangkat. `null` bila Firebase belum memberi token.
  final String? token;
  final bool permissionGranted;

  /// `true` bila backend menerima token lewat `POST /devices`.
  final bool registeredOnBackend;

  /// Aksi pelepasan. Pemakai sebaiknya memanggil [stop], bukan field ini,
  /// supaya pelepasan tidak terjadi dua kali.
  final Future<void> Function() onStop;

  bool _stopped = false;

  /// Melepas listener dan menghentikan langganan topik. Aman dipanggil dua kali.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    await onStop();
  }
}
