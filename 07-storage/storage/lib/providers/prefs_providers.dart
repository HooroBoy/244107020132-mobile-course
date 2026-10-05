import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prefs.dart';

final prefsRepositoryProvider = Provider<PrefsRepository>(
  (ref) => PrefsRepository(),
);

final darkModeProvider = AsyncNotifierProvider<DarkModeNotifier, bool>(
  DarkModeNotifier.new,
);

class DarkModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(prefsRepositoryProvider).getDarkMode();

  Future<void> setDarkMode(bool value) async {
    final previous = state.value ?? false;
    state = AsyncData(value);
    try {
      await ref.read(prefsRepositoryProvider).setDarkMode(value);
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> toggle() => setDarkMode(!(state.value ?? false));
}

/// Mengembalikan waktu sesi sebelumnya, lalu menyimpan waktu sesi saat ini.
final lastOpenedProvider = FutureProvider<String?>((ref) async {
  final repository = ref.watch(prefsRepositoryProvider);
  final previous = await repository.getLastOpened();
  await repository.markOpenedNow();
  return previous;
});
