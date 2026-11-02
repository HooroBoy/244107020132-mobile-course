import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/routes.dart';
import '../pages/announcement_page.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/notifications_page.dart';
import 'auth/auth_controller.dart';

/// GoRouter dibuat sekali; perubahan status login memicu redirect lewat
/// [refreshListenable], bukan dengan membuat router baru.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);

      // Token sedang dibaca dari secure storage: jangan ambil keputusan dulu,
      // kalau tidak pengguna yang sah akan terlempar ke /login sesaat.
      if (auth.isLoading && !auth.hasValue) return null;

      final bool loggedIn = auth.value != null;
      final bool atLogin = state.matchedLocation == Routes.login;

      if (!loggedIn && !atLogin) return Routes.login;
      if (loggedIn && atLogin) return Routes.home;
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: Routes.notifications,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: Routes.announcementPattern,
        builder: (context, state) => AnnouncementPage(
          id: state.pathParameters[Routes.announcementIdParam] ?? '',
        ),
      ),
    ],
  );
});

/// Menjembatani Riverpod -> [Listenable] yang dipakai GoRouter.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _subscription = ref.listen<AsyncValue<AuthSession?>>(
      authControllerProvider,
      (previous, next) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<AuthSession?>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
