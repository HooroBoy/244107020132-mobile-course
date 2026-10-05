import 'package:flutter/material.dart';

import '../data/local/note.dart';

typedef NoteFormResult = ({String title, String body});

class NoteFormDialog extends StatefulWidget {
  const NoteFormDialog({super.key, this.initial});

  final Note? initial;

  @override
  State<NoteFormDialog> createState() => _NoteFormDialogState();
}

class _NoteFormDialogState extends State<NoteFormDialog> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  late final TextEditingController _bodyController = TextEditingController(
    text: widget.initial?.body ?? '',
  );
  String? _titleError;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Judul wajib diisi');
      return;
    }

    Navigator.of(context)
        .pop<NoteFormResult>((title: title, body: _bodyController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        widget.initial == null ? Icons.note_add_outlined : Icons.edit_note,
      ),
      title: Text(widget.initial == null ? 'Catatan baru' : 'Ubah catatan'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('note-title-field'),
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Judul',
                hintText: 'Contoh: Belanja mingguan',
                errorText: _titleError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('note-body-field'),
              controller: _bodyController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Isi catatan',
                hintText: 'Tulis detail catatan di sini',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          key: const Key('save-note-button'),
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Simpan'),
        ),
      ],
    );
  }
}
