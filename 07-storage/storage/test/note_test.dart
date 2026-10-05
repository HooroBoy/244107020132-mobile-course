import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage/data/local/note.dart';
import 'package:storage/data/remote/post.dart';
import 'package:storage/data/repositories/note_repository.dart';
import 'package:storage/data/repositories/post_repository.dart';
import 'package:storage/data/sync.dart';
import 'package:storage/providers/note_providers.dart';
import 'package:storage/providers/offline_providers.dart';
import 'package:storage/providers/post_providers.dart';

class FakeNoteRepository extends NoteRepository {
  FakeNoteRepository({List<Note> items = const [], this.throwError = false})
    : items = [...items],
      super(
        openDb: () => throw UnimplementedError('Database tidak boleh dipakai'),
      );

  final List<Note> items;
  final bool throwError;

  @override
  Future<List<Note>> fetchNotes() async {
    if (throwError) throw Exception('db locked (simulasi)');
    return items;
  }

  @override
  Future<int> countDirty() async => items.where((note) => note.dirty).length;

  @override
  Future<void> markAllSynced() async {
    for (var index = 0; index < items.length; index++) {
      items[index] = items[index].copyWith(dirty: false);
    }
  }
}

class FakePostRepository extends PostRepository {
  FakePostRepository({required this.cached})
    : super(
        openDb: () => throw UnimplementedError('Database tidak boleh dipakai'),
      );

  final List<Post> cached;
  var networkCallCount = 0;

  @override
  Future<List<Post>> readCachedPosts() async => cached;

  @override
  Future<List<Post>> fetchAndCache() async {
    networkCallCount++;
    throw StateError('Jaringan tidak boleh dipanggil saat offline');
  }
}

Note createNote(String title, {bool dirty = false, DateTime? updatedAt}) {
  return Note(
    title: title,
    updatedAt: updatedAt ?? DateTime(2026, 9, 18),
    dirty: dirty,
  );
}

void main() {
  group('Model Note', () {
    test('fromMap aman terhadap field yang hilang', () {
      final note = Note.fromMap({'title': 'Belanja'});

      expect(note.title, 'Belanja');
      expect(note.body, '');
      expect(note.dirty, isFalse);
      expect(note.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('flag dirty dan waktu bertahan pada serialisasi', () {
      final note = createNote('Tes serialisasi', dirty: true);
      final restored = Note.fromMap(note.toMap());

      expect(restored.dirty, isTrue);
      expect(restored.updatedAt, note.updatedAt);
      expect(restored.title, note.title);
    });
  });

  group('Model Post', () {
    test('fromJson memberi nilai bawaan untuk data opsional', () {
      final post = Post.fromJson({'id': 7});

      expect(post.id, 7);
      expect(post.title, '');
      expect(post.body, '');
    });
  });

  group('Provider dengan repository palsu', () {
    test('notesProvider meneruskan data repository', () async {
      final container = ProviderContainer(
        overrides: [
          noteRepositoryProvider.overrideWithValue(
            FakeNoteRepository(items: [createNote('Tes provider')]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notes = await container.read(notesProvider.future);

      expect(notes, hasLength(1));
      expect(notes.first.title, 'Tes provider');
    });

    test('notesProvider meneruskan error sebagai state error', () async {
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          noteRepositoryProvider.overrideWithValue(
            FakeNoteRepository(throwError: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(notesProvider.future),
        throwsA(isA<Exception>()),
      );
    });

    test('postsProvider memakai cache tanpa jaringan saat offline', () async {
      final repository = FakePostRepository(
        cached: const [Post(id: 1, title: 'Cache', body: 'Data lokal')],
      );
      final container = ProviderContainer(
        overrides: [postRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      container.read(forceOfflineProvider.notifier).setOffline(true);

      final posts = await container.read(postsProvider.future);

      expect(posts.single.title, 'Cache');
      expect(repository.networkCallCount, 0);
    });
  });

  group('Offline-first', () {
    test('syncNotes membersihkan semua catatan dirty', () async {
      final repository = FakeNoteRepository(
        items: [
          createNote('a', dirty: true),
          createNote('b', dirty: true),
          createNote('c'),
        ],
      );

      final synced = await syncNotes(repository, latency: Duration.zero);

      expect(synced, 2);
      expect(await repository.countDirty(), 0);
    });

    test('syncNotes saat offline menjaga antrean dirty', () async {
      final repository = FakeNoteRepository(
        items: [createNote('tertunda', dirty: true)],
      );

      await expectLater(
        syncNotes(repository, offline: true, latency: Duration.zero),
        throwsA(isA<OfflineException>()),
      );
      expect(await repository.countDirty(), 1);
    });

    test('resolveConflict selalu memilih updatedAt terbaru', () {
      final local = createNote('lokal', updatedAt: DateTime(2026, 9, 18, 10));
      final remote = createNote('server', updatedAt: DateTime(2026, 9, 18, 11));

      expect(resolveConflict(local, remote).title, 'server');
      expect(resolveConflict(remote, local).title, 'server');
    });
  });
}
