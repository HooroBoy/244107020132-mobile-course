import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tujuan deep link notifikasi: `/pengumuman/:id`.
///
/// Halaman ini sengaja membaca `id` dari path, bukan dari state halaman lain,
/// supaya bisa dibuka langsung dari notifikasi pada ketiga app state.
class AnnouncementPage extends StatelessWidget {
  const AnnouncementPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengumuman'),
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Chip(
            avatar: const Icon(Icons.tag, size: 18),
            label: Text('id: $id'),
          ),
          const SizedBox(height: 16),
          Text(
            'Jadwal kuliah berubah',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kelas Mobile pindah ke Ruang A2 jam 13.00.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Halaman ini adalah target deep link',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Notifikasi FCM membawa data.route = /pengumuman/$id. '
                    'Dari foreground, background, maupun terminated, klik '
                    'notifikasi harus mendarat di halaman ini dengan id yang '
                    'sama.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
