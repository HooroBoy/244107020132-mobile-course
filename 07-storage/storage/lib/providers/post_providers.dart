import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/post.dart';
import '../data/repositories/post_repository.dart';
import '../data/sync.dart';
import 'offline_providers.dart';

final postRepositoryProvider = Provider<PostRepository>(
  (ref) => PostRepository(),
);

final postsProvider = AsyncNotifierProvider<PostsNotifier, List<Post>>(
  PostsNotifier.new,
);

class PostsNotifier extends AsyncNotifier<List<Post>> {
  @override
  Future<List<Post>> build() async {
    final repository = ref.watch(postRepositoryProvider);
    final offline = ref.watch(forceOfflineProvider);
    final cached = await repository.readCachedPosts();

    if (offline) {
      if (cached.isEmpty) {
        throw const OfflineException(
          'Offline dan belum ada cache. Buka halaman ini sekali saat online.',
        );
      }
      return cached;
    }

    if (cached.isEmpty) return repository.fetchAndCache();

    unawaited(_refreshInBackground(repository));
    return cached;
  }

  Future<void> _refreshInBackground(PostRepository repository) async {
    try {
      final fresh = await repository.fetchAndCache();
      state = AsyncData(fresh);
    } catch (_) {
      // Cache tetap dipakai ketika refresh jaringan gagal.
    }
  }

  Future<bool> refresh() async {
    if (ref.read(forceOfflineProvider)) return false;
    try {
      final fresh = await ref.read(postRepositoryProvider).fetchAndCache();
      state = AsyncData(fresh);
      return true;
    } catch (_) {
      return false;
    }
  }
}
