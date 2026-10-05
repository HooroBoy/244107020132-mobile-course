import 'local/note.dart';
import 'repositories/note_repository.dart';

class OfflineException implements Exception {
  const OfflineException(this.message);

  final String message;

  @override
  String toString() => 'OfflineException: $message';
}

/// Mengirim antrean catatan dirty ke server simulasi.
Future<int> syncNotes(
  NoteRepository repository, {
  bool offline = false,
  Duration latency = const Duration(seconds: 1),
}) async {
  if (offline) {
    throw const OfflineException('Perangkat offline, sinkronisasi ditunda.');
  }

  final dirtyCount = await repository.countDirty();
  if (dirtyCount == 0) return 0;

  await Future<void>.delayed(latency);
  await repository.markAllSynced();
  return dirtyCount;
}

/// Resolusi konflik deterministik dengan strategi last-write-wins.
Note resolveConflict(Note local, Note remote) {
  return remote.updatedAt.isAfter(local.updatedAt) ? remote : local;
}
