import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/offline_providers.dart';
import '../providers/post_providers.dart';

class PostsPage extends ConsumerWidget {
  const PostsPage({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final succeeded = await ref.read(postsProvider.notifier).refresh();
    if (!succeeded && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal refresh, menampilkan cache lokal')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(postsProvider);
    final offline = ref.watch(forceOfflineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bacaan cache-first')),
      body: Column(
        children: [
          if (offline)
            MaterialBanner(
              leading: const Icon(Icons.cloud_off),
              content: const Text(
                'Mode offline aktif. Data ditampilkan dari cache lokal.',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      ref.read(forceOfflineProvider.notifier).setOffline(false),
                  child: const Text('ONLINE'),
                ),
              ],
            ),
          Expanded(
            child: posts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _PostsErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(postsProvider),
              ),
              data: (items) => RefreshIndicator(
                onRefresh: () => _refresh(context, ref),
                child: items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 160),
                          Icon(Icons.article_outlined, size: 64),
                          SizedBox(height: 12),
                          Center(child: Text('Belum ada posts')),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final post = items[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 6,
                            ),
                            leading: CircleAvatar(child: Text('${post.id}')),
                            title: Text(
                              post.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              post.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostsErrorView extends StatelessWidget {
  const _PostsErrorView({required this.message, required this.onRetry});

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
            const Icon(Icons.cloud_off, size: 56),
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
