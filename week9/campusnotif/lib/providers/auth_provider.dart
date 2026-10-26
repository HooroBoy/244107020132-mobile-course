import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/auth_repository.dart';
import '../data/token_store.dart';

/// Dependency yang bisa di-override saat test (fake store / fake repository).
final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(),
);

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const AuthRepository(),
);

/// Klien API yang sudah membawa interceptor refresh.
///
/// Saat sesi tidak bisa dipulihkan, [AuthNotifier.forceLogout] dipanggil
/// sehingga guard route langsung melempar pengguna ke `/login`.
final Provider<Dio> apiClientProvider = Provider<Dio>((ref) {
  return buildApiClient(
    store: ref.watch(tokenStoreProvider),
    auth: ref.watch(authRepositoryProvider),
    onSessionExpired: () => ref.read(authStateProvider.notifier).forceLogout(),
  );
});

/// Status sesi: `null` berarti belum login.
final AsyncNotifierProvider<AuthNotifier, AuthSession?> authStateProvider =
    AsyncNotifierProvider<AuthNotifier, AuthSession?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final store = ref.watch(tokenStoreProvider);

    final access = await store.readAccess();
    if (access == null || access.isEmpty) return null;

    final refresh = await store.readRefresh();
    if (refresh == null || refresh.isEmpty) {
      // Setengah sesi tersimpan = data tidak konsisten, bersihkan.
      await store.clear();
      return null;
    }

    return AuthSession(
      access: access,
      refresh: refresh,
      email: await store.readEmail(),
    );
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      await ref.read(tokenStoreProvider).save(
            access: session.access,
            refresh: session.refresh,
            email: session.email,
          );
      return session;
    });
  }

  /// Menukar refresh token dengan access token baru tanpa mengubah identitas.
  ///
  /// Mengembalikan `false` bila refresh ditolak: sesi dibersihkan dan guard
  /// route akan memindahkan pengguna ke `/login`.
  Future<bool> refreshSession() async {
    final store = ref.read(tokenStoreProvider);
    final refresh = await store.readRefresh();
    if (refresh == null || refresh.isEmpty) {
      await forceLogout();
      return false;
    }

    try {
      final renewed = await ref.read(authRepositoryProvider).refresh(refresh);
      await store.save(access: renewed, refresh: refresh);
      state = AsyncData(
        AuthSession(
          access: renewed,
          refresh: refresh,
          email: state.value?.email,
        ),
      );
      return true;
    } on Object {
      await forceLogout();
      return false;
    }
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncData(null);
  }

  /// Dipakai interceptor ketika refresh token sudah mati: bersihkan sesi
  /// tanpa melempar exception ke UI.
  Future<void> forceLogout() async {
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncData(null);
  }
}
