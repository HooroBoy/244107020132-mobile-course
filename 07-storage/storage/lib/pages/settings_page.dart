import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/offline_providers.dart';
import '../providers/prefs_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  String _formatLastOpened(String? value) {
    if (value == null) return 'Baru pertama kali dibuka';
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(darkModeProvider);
    final lastOpened = ref.watch(lastOpenedProvider);
    final offline = ref.watch(forceOfflineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionTitle(title: 'Tampilan'),
          darkMode.when(
            loading: () => const ListTile(
              leading: Icon(Icons.dark_mode_outlined),
              title: Text('Memuat preferensi...'),
              trailing: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, _) => ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Gagal memuat preferensi'),
              subtitle: Text('$error'),
              trailing: IconButton(
                tooltip: 'Coba lagi',
                onPressed: () => ref.invalidate(darkModeProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
            data: (isDark) => SwitchListTile(
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
              title: const Text('Tema gelap'),
              subtitle: const Text('Disimpan di SharedPreferences'),
              value: isDark,
              onChanged: (value) async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(darkModeProvider.notifier).setDarkMode(value);
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Gagal menyimpan tema')),
                  );
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Terakhir dibuka'),
            subtitle: Text(
              lastOpened.when(
                data: _formatLastOpened,
                loading: () => 'Memuat...',
                error: (error, _) => 'Gagal dibaca: $error',
              ),
            ),
          ),
          const Divider(height: 32),
          const _SectionTitle(title: 'Koneksi & pengujian'),
          SwitchListTile(
            secondary: const Icon(Icons.wifi_off),
            title: const Text('Paksa mode offline'),
            subtitle: const Text(
              'Simulasi offline yang deterministik untuk demo dan testing',
            ),
            value: offline,
            onChanged: (value) =>
                ref.read(forceOfflineProvider.notifier).setOffline(value),
          ),
          if (offline)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sinkronisasi ditunda. Catatan lokal tetap dapat dibuat, diubah, dan dihapus.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
