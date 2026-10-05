import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/local/note.dart';
import '../data/sync.dart';
import '../providers/note_providers.dart';
import '../providers/offline_providers.dart';
import '../widgets/note_form_dialog.dart';
import '../widgets/note_tile.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  bool _syncing = false;

  Future<void> _openCreateForm() async {
    final result = await showDialog<NoteFormResult>(
      context: context,
      builder: (_) => const NoteFormDialog(),
    );
    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(noteActionsProvider).add(result.title, result.body);
      messenger.showSnackBar(
        const SnackBar(content: Text('Catatan disimpan di perangkat')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan catatan: $error')),
      );
    }
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Hapus catatan?'),
        content: Text('“${note.title}” akan dihapus dari perangkat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || note.id == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(noteActionsProvider).delete(note.id!);
      messenger.showSnackBar(
        const SnackBar(content: Text('Catatan berhasil dihapus')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menghapus catatan: $error')),
      );
    }
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await ref.read(noteActionsProvider).sync();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'Semua catatan sudah tersinkron'
                : '$count catatan berhasil disinkronkan',
          ),
        ),
      );
    } on OfflineException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Sinkronisasi gagal: $error')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final dirtyCount = ref.watch(dirtyCountProvider).value ?? 0;
    final offline = ref.watch(forceOfflineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Offline Notes'),
            Text(
              'Tersimpan lokal, siap kapan saja',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          Badge(
            isLabelVisible: dirtyCount > 0,
            label: Text('$dirtyCount'),
            child: IconButton(
              tooltip: offline
                  ? 'Offline: sinkronisasi ditunda'
                  : 'Sinkronkan catatan',
              onPressed: _syncing ? null : _sync,
              icon: _syncing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(offline ? Icons.cloud_off : Icons.sync),
            ),
          ),
          IconButton(
            tooltip: 'Posts cache-first',
            onPressed: () => context.push('/posts'),
            icon: const Icon(Icons.article_outlined),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (offline)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.tertiaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                children: [
                  Icon(Icons.cloud_off, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mode offline aktif • Perubahan disimpan lokal',
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: notes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorView(
                message: 'Gagal membaca database:\n$error',
                onRetry: () => ref.invalidate(notesProvider),
              ),
              data: (items) {
                if (items.isEmpty) return const _EmptyView();
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(notesProvider);
                    await ref.read(notesProvider.future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final note = items[index];
                      return NoteTile(
                        key: ValueKey(note.id),
                        note: note,
                        onTap: () => context.push('/note/${note.id}'),
                        onDelete: () => _deleteNote(note),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-note-button'),
        onPressed: _openCreateForm,
        icon: const Icon(Icons.add),
        label: const Text('Catatan'),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              'Belum ada catatan',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Tekan tombol Catatan untuk menyimpan ide pertama Anda secara lokal.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
