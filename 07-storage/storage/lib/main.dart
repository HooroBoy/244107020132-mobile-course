import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'pages/note_detail_page.dart';
import 'pages/notes_page.dart';
import 'pages/posts_page.dart';
import 'pages/settings_page.dart';
import 'providers/prefs_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: OfflineNotesApp()));
}

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const NotesPage(),
      routes: [
        GoRoute(
          path: 'note/:id',
          builder: (context, state) => NoteDetailPage(
            id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
          ),
        ),
        GoRoute(path: 'posts', builder: (context, state) => const PostsPage()),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);

class OfflineNotesApp extends ConsumerWidget {
  const OfflineNotesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(darkModeProvider).value ?? false;
    // Mulai pencatatan sesi saat aplikasi dibuka, bukan saat halaman pengaturan
    // pertama kali dikunjungi.
    ref.watch(lastOpenedProvider);
    const seedColor = Color(0xFF4F46E5);

    return MaterialApp.router(
      title: 'Offline Notes',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        scaffoldBackgroundColor: const Color(0xFFF8F9FC),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: const CardThemeData(elevation: 0),
        inputDecorationTheme: const InputDecorationTheme(filled: true),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: const CardThemeData(elevation: 0),
        inputDecorationTheme: const InputDecorationTheme(filled: true),
      ),
    );
  }
}
