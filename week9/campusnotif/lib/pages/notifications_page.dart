import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/notification_store.dart';
import '../data/relative_time.dart';
import '../providers/notification_providers.dart';
import '../routes.dart';

/// Daftar notifikasi yang **belum dibaca**.
///
/// Mengetuk satu entri berarti membacanya: entri itu langsung dihapus dari
/// daftar dan badge ikon aplikasi ikut berkurang. Panjang daftar selalu sama
/// dengan angka pada badge.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // Handler FCM di background menulis ke penyimpanan dari isolate lain, jadi
    // daftar di memori bisa tertinggal satu entri. Membaca ulang setiap halaman
    // dibuka membuat isi yang dilihat pengguna selalu sama dengan penyimpanan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(notificationsProvider.notifier).reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<AppNotification> items = ref.watch(notificationsProvider);
    final NotificationCenter center = ref.read(notificationsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          items.isEmpty ? 'Notifikasi' : 'Notifikasi (${items.length})',
        ),
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Routes.home);
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        actions: <Widget>[
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'Tandai semua dibaca',
              onPressed: center.markAllRead,
              icon: const Icon(Icons.done_all),
            ),
        ],
      ),
      body: items.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
              onRefresh: center.reload,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) =>
                    _NotificationTile(
                  item: items[index],
                  onRead: () => center.markRead(items[index].id),
                ),
              ),
            ),
    );
  }
}

/// Satu baris notifikasi. Mengetuk = membaca: entri dihapus lalu rute dibuka.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onRead});

  final AppNotification item;
  final Future<void> Function() onRead;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await onRead();
          if (!context.mounted) return;
          await context.push(item.route);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.campaign_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          relativeTime(item.receivedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (item.body.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      item.route,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.notifications_off_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Tidak ada notifikasi baru',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Notifikasi yang sudah dibaca akan hilang dari daftar ini.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
