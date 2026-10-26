import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';
import '../providers/push_providers.dart';
import '../routes.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AuthSession?> auth = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Notify'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Keluar',
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _buildBody(context, ref, auth),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<AuthSession?> auth,
  ) {
    // Token masih dibaca dari secure storage saat aplikasi dibuka.
    if (auth.isLoading && !auth.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (auth.hasError && !auth.hasValue) {
      return _ErrorView(
        message: '${auth.error}',
        onRetry: () => ref.invalidate(authStateProvider),
      );
    }
    return _SessionView(session: auth.value);
  }
}

class _SessionView extends ConsumerWidget {
  const _SessionView({required this.session});

  final AuthSession? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    if (session == null) {
      // Guard GoRouter seharusnya sudah memindahkan pengguna ke /login;
      // tampilan ini hanya jaring pengaman.
      return const Center(child: Text('Belum ada sesi.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Sesi aktif',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _Row(label: 'Email', value: session!.email ?? '-'),
                const SizedBox(height: 8),
                _Row(
                  label: 'Access token',
                  value: session!.maskedAccess,
                  note: 'disimpan di flutter_secure_storage',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: const Text('Jadwal kuliah berubah'),
                subtitle: const Text('Contoh halaman tujuan deep link FCM'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(Routes.announcement('3')),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Uji refresh token'),
                subtitle: const Text(
                  'Tukar refresh token dengan access token baru',
                ),
                onTap: () async {
                  final ScaffoldMessengerState messenger =
                      ScaffoldMessenger.of(context);
                  final bool ok =
                      await ref.read(authStateProvider.notifier).refreshSession();
                  if (!context.mounted) return;

                  final AuthSession? session = ref.read(authStateProvider).value;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Token diperbarui: ${session?.maskedAccess ?? '-'}'
                            : 'Refresh ditolak. Sesi dihapus, silakan login ulang.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _PushCard(),
      ],
    );
  }
}

/// Status FCM + tombol uji banner lokal. Isi kartu ini dipakai sebagai bukti
/// pengujian di README (token terpotong, status izin, status topik).
class _PushCard extends ConsumerWidget {
  const _PushCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final PushState push = ref.watch(pushProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.notifications_active_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status notifikasi',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Row(
              label: 'FCM token',
              value: push.maskedToken,
              note: 'token terpotong, tidak pernah ditampilkan utuh',
            ),
            const SizedBox(height: 8),
            _Row(
              label: 'Izin notifikasi',
              value: push.permissionGranted ? 'diberikan' : 'belum / ditolak',
            ),
            const SizedBox(height: 8),
            _Row(
              label: 'Topik',
              value: push.subscribedTopic
                  ? 'pengumuman-kampus (terdaftar)'
                  : 'belum terdaftar',
            ),
            const SizedBox(height: 8),
            _Row(
              label: 'Laporan token ke backend',
              value: push.registeredOnBackend
                  ? 'POST /devices berhasil'
                  : 'POST /devices belum berhasil',
            ),
            if (push.lastRoute != null) ...<Widget>[
              const SizedBox(height: 8),
              _Row(label: 'Deep link terakhir', value: push.lastRoute!),
            ],
            if (push.note != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                push.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(pushProvider.notifier).sendTestNotification(),
              icon: const Icon(Icons.notifications_none),
              label: const Text('Tampilkan notifikasi uji'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: theme.textTheme.bodyMedium,
        ),
        if (note != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            note!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
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
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
