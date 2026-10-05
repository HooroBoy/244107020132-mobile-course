import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/local/note.dart';
import '../providers/note_providers.dart';
import '../widgets/note_form_dialog.dart';

class NoteDetailPage extends ConsumerWidget {
  const NoteDetailPage({super.key, required this.id});

  final int id;

  Future<void> _edit(BuildContext context, WidgetRef ref, Note note) async {
    final result = await showDialog<NoteFormResult>(
      context: context,
      builder: (_) => NoteFormDialog(initial: note),
    );
    if (result == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(noteActionsProvider)
          .update(note.copyWith(title: result.title, body: result.body));
      messenger.showSnackBar(
        const SnackBar(content: Text('Perubahan disimpan secara lokal')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal mengubah catatan: $error')),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Hapus catatan?'),
        content: Text('“${note.title}” akan dihapus permanen dari perangkat.'),
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
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(noteActionsProvider).delete(note.id!);
      if (context.mounted) context.pop();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menghapus catatan: $error')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year}, '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(noteByIdProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail catatan')),
      body: note.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DetailMessage(
          icon: Icons.error_outline,
          title: 'Catatan gagal dibuka',
          message: '$error',
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(noteByIdProvider(id)),
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ),
        data: (item) {
          if (item == null) {
            return const _DetailMessage(
              icon: Icons.search_off,
              title: 'Catatan tidak ditemukan',
              message: 'Catatan mungkin sudah dihapus dari perangkat.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Icon(
                    item.dirty ? Icons.cloud_off : Icons.cloud_done,
                    color: item.dirty ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.dirty ? 'Belum tersinkron' : 'Sudah tersinkron',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                item.title,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Diperbarui ${_formatDate(item.updatedAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: 40),
              Text(
                item.body.isEmpty ? '(tanpa isi)' : item.body,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => _edit(context, ref, item),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Ubah'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _delete(context, ref, item),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
