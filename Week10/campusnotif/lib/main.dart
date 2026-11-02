import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/messaging/firebase_bootstrap.dart';
import 'domain/entities/auth_session.dart';
import 'presentation/providers/app_router.dart';
import 'presentation/providers/auth/auth_controller.dart';
import 'presentation/providers/dependencies.dart';
import 'presentation/providers/notifications/notification_controller.dart';
import 'presentation/providers/push/push_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase diinisialisasi lebih dulu karena FCM butuh instance yang siap.
  // Bila google-services.json belum ada, aplikasi tetap berjalan tanpa FCM.
  final FirebaseBootstrap firebase = await bootstrapFirebase();

  runApp(
    ProviderScope(
      // Kesiapan Firebase menentukan sumber autentikasi: Firebase Auth bila
      // siap, mock bila google-services.json belum ada.
      overrides: [
        firebaseReadyProvider.overrideWithValue(firebase.ready),
      ],
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
  late final AppLifecycleListener _lifecycle;
  late final ProviderSubscription<AsyncValue<AuthSession?>> _authListener;

  /// Router baru siap dipakai bernavigasi setelah frame pertama selesai.
  bool _frameReady = false;

  @override
  void initState() {
    super.initState();

    // Saat aplikasi di background, handler FCM menulis langsung ke penyimpanan
    // (isolate terpisah), sehingga daftar di memori menjadi basi: lonceng dan
    // badge ikon tidak ikut bertambah sampai aplikasi dibuka ulang. Karena itu
    // kotak masuk dibaca ulang setiap aplikasi kembali aktif.
    _lifecycle = AppLifecycleListener(onResume: _reloadInbox);

    // Logout melepas perangkat dari backend (lihat `LogoutUseCase`), jadi sesi
    // berikutnya harus memasang FCM lagi. `start()` menjaga dirinya sendiri agar
    // tidak berjalan dua kali.
    _authListener = ref.listenManual<AsyncValue<AuthSession?>>(
      authControllerProvider,
      (previous, next) {
        if (previous?.value == null && next.value != null && _frameReady) {
          // Ditunda agar perubahan state push tidak terjadi di tengah
          // notifikasi provider auth.
          Future<void>.microtask(_startPush);
        }
      },
    );

    // Ditunda satu frame: router harus sudah terpasang sebelum
    // getInitialMessage() mencoba bernavigasi. Penanda ini juga menahan
    // `_startPush` dari listener auth yang menyala terlalu dini.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameReady = true;
      _startPush();
    });
  }

  void _startPush() {
    if (!mounted) return;
    ref.read(pushProvider.notifier).start(
          firebaseReady: widget.firebase.ready,
          firebaseNote: widget.firebase.reason,
        );
  }

  void _reloadInbox() {
    if (!mounted) return;
    ref.read(notificationsProvider.notifier).reload();
  }

  @override
  void dispose() {
    _authListener.close();
    _lifecycle.dispose();
    super.dispose();
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
