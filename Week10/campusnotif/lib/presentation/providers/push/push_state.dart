import '../../../domain/utils/masking.dart';

/// Penanda "argumen tidak diberikan" untuk [PushState.copyWith].
///
/// Diperlukan karena `null` pada parameter `Object?` tidak bisa dibedakan dari
/// "tidak diisi", padahal `copyWith(note: null)` harus bisa mengosongkan note.
const Object _unset = Object();

/// Status FCM yang ditampilkan di UI sebagai bukti pengujian.
///
/// Ini state presentasi, bukan entity domain: isinya campuran hasil use case dan
/// teks yang siap dibaca pengguna.
class PushState {
  const PushState({
    this.started = false,
    this.permissionGranted = false,
    this.token,
    this.registeredOnBackend = false,
    this.subscribedTopic = false,
    this.lastRoute,
    this.note,
  });

  final bool started;
  final bool permissionGranted;

  /// Token utuh; hanya dipakai internal. UI memakai [maskedToken].
  final String? token;
  final bool registeredOnBackend;
  final bool subscribedTopic;
  final String? lastRoute;
  final String? note;

  /// Token terpotong untuk ditampilkan / difoto.
  String get maskedToken => token == null ? '-' : maskSecret(token!);

  /// Menyalin state dengan sebagian nilai diganti.
  ///
  /// [token], [lastRoute], dan [note] menerima `null` sebagai perintah
  /// **mengosongkan** nilai lama — dipakai saat catatan error sudah tidak
  /// berlaku atau saat perangkat dilepas ketika logout. Parameter yang tidak
  /// disebut sama sekali dibedakan lewat [_unset].
  PushState copyWith({
    bool? started,
    bool? permissionGranted,
    Object? token = _unset,
    bool? registeredOnBackend,
    bool? subscribedTopic,
    Object? lastRoute = _unset,
    Object? note = _unset,
  }) {
    return PushState(
      started: started ?? this.started,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      token: _stringOr(token, this.token),
      registeredOnBackend: registeredOnBackend ?? this.registeredOnBackend,
      subscribedTopic: subscribedTopic ?? this.subscribedTopic,
      lastRoute: _stringOr(lastRoute, this.lastRoute),
      note: _stringOr(note, this.note),
    );
  }

  /// `null` berarti kosongkan; [_unset] berarti pertahankan nilai lama.
  static String? _stringOr(Object? value, String? fallback) =>
      identical(value, _unset) ? fallback : value as String?;
}
