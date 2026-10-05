import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/note.dart';
import '../data/repositories/note_repository.dart';
import '../data/sync.dart';
import 'offline_providers.dart';

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(),
);

final notesProvider = FutureProvider<List<Note>>(
  (ref) => ref.watch(noteRepositoryProvider).fetchNotes(),
);

final noteByIdProvider = FutureProvider.family<Note?, int>(
  (ref, id) => ref.watch(noteRepositoryProvider).getNoteById(id),
);

final dirtyCountProvider = FutureProvider<int>(
  (ref) => ref.watch(noteRepositoryProvider).countDirty(),
);

final noteActionsProvider = Provider<NoteActions>((ref) => NoteActions(ref));

class NoteActions {
  NoteActions(this._ref);

  final Ref _ref;

  NoteRepository get _repository => _ref.read(noteRepositoryProvider);

  Future<void> add(String title, String body) async {
    await _repository.addNote(title: title, body: body);
    _refreshList();
  }

  Future<void> update(Note note) async {
    await _repository.updateNote(note);
    _refreshList();
    if (note.id case final id?) {
      _ref.invalidate(noteByIdProvider(id));
    }
  }

  Future<void> delete(int id) async {
    await _repository.deleteNote(id);
    _refreshList();
    _ref.invalidate(noteByIdProvider(id));
  }

  Future<int> sync() async {
    final count = await syncNotes(
      _repository,
      offline: _ref.read(forceOfflineProvider),
    );
    _refreshList();
    _ref.invalidate(noteByIdProvider);
    return count;
  }

  void _refreshList() {
    _ref.invalidate(notesProvider);
    _ref.invalidate(dirtyCountProvider);
  }
}
