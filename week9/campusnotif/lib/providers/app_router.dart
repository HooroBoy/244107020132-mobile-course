import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_repository.dart';
import '../pages/announcement_page.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../routes.dart';
import 'auth_provider.dart';

/// GoRouter dibuat sekali; perubahan status login memicu redirect lewat
/// [refreshListenable], bukan dengan membuat router baru.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);

      // Token sedang dibaca dari secure storage: jangan ambil keputusan dulu,
      // kalau tidak pengguna yang sah akan terlempar ke /login sesaat.
      if (auth.isLoading && !auth.hasValue) return null;

      final loggedIn = auth.value != null;
      final atLogin = state.matchedLocation == Routes.login;

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
      authStateProvider,
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
