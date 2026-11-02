import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/auth_session.dart';
import '../dependencies.dart';

/// Status sesi: `null` berarti belum login.
///
/// Controller ini hanya mengurus *state*: kapan loading, kapan error, kapan
/// sesi kosong. Urutan kerja sebenarnya (login → simpan, refresh → simpan,
/// logout → lepas perangkat) ada di use case, sehingga kelas ini tetap kecil.
final AsyncNotifierProvider<AuthController, AuthSession?>
    authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() => ref.watch(restoreSessionUseCaseProvider)();

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(loginUseCaseProvider)(email: email, password: password),
    );
  }

  /// Menukar refresh token dengan access token baru tanpa mengubah identitas.
  ///
  /// Mengembalikan `false` bila refresh ditolak: sesi dibersihkan dan guard
  /// route akan memindahkan pengguna ke `/login`.
  Future<bool> refreshSession() async {
    try {
      state = AsyncData(await ref.read(refreshSessionUseCaseProvider)());
      return true;
    } on Object {
      await forceLogout();
      return false;
    }
  }

  /// Keluar: lepas perangkat dari backend, hentikan langganan topik, hapus sesi.
  ///
  /// Kegagalan jaringan tidak boleh menahan pengguna di dalam aplikasi, jadi
  /// sesi lokal tetap dibersihkan pada cabang gagal.
  Future<void> logout() async {
    try {
      await ref.read(logoutUseCaseProvider)();
    } on Object {
      await _discardLocalSession();
    }
    state = const AsyncData(null);
  }

  /// Dipakai interceptor ketika refresh token sudah mati: bersihkan sesi tanpa
  /// melempar exception ke UI.
  Future<void> forceLogout() async {
    await _discardLocalSession();
    state = const AsyncData(null);
  }

  /// Menghapus token lokal **dan** sesi penyedia auth (bila ada).
  ///
  /// Tanpa `signOut()`, SDK Firebase akan memulihkan sesinya sendiri saat
  /// aplikasi dibuka karena SDK masih menyimpan sesinya.
  Future<void> _discardLocalSession() async {
    await ref.read(sessionRepositoryProvider).clear();
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on Object {
      // Kegagalan signOut tidak boleh menghalangi logout lokal.
    }
  }
}
