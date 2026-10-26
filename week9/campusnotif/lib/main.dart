import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'messaging/firebase_bootstrap.dart';
import 'providers/app_router.dart';
import 'providers/push_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase diinisialisasi lebih dulu karena FCM butuh instance yang siap.
  // Bila google-services.json belum ada, aplikasi tetap berjalan tanpa FCM.
  final FirebaseBootstrap firebase = await bootstrapFirebase();

  runApp(
    ProviderScope(
      child: CampusNotifyApp(firebase: firebase),
    ),
  );
}

class CampusNotifyApp extends ConsumerStatefulWidget {
  const CampusNotifyApp({super.key, required this.firebase});

  final FirebaseBootstrap firebase;

  @override
  ConsumerState<CampusNotifyApp> createState() => _CampusNotifyAppState();
}

class _CampusNotifyAppState extends ConsumerState<CampusNotifyApp> {
  @override
  void initState() {
    super.initState();
    // Ditunda satu frame: router harus sudah terpasang sebelum
    // getInitialMessage() mencoba bernavigasi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pushProvider.notifier).start(
            firebaseReady: widget.firebase.ready,
            firebaseNote: widget.firebase.reason,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Campus Notify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B6E4F),
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
