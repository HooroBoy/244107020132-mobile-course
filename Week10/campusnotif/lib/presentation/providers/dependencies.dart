import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/key_value_store.dart';
import '../../data/http/api_client.dart';
import '../../data/messaging/fcm_push_messaging.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../data/repositories/http_device_repository.dart';
import '../../data/repositories/launcher_badge.dart';
import '../../data/repositories/mock_auth_repository.dart';
import '../../data/repositories/secure_session_repository.dart';
import '../../data/repositories/shared_prefs_inbox_repository.dart';
import '../../domain/repositories/app_badge.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/device_repository.dart';
import '../../domain/repositories/notification_inbox_repository.dart';
import '../../domain/repositories/push_messaging.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/usecases/auth/login_usecase.dart';
import '../../domain/usecases/auth/logout_usecase.dart';
import '../../domain/usecases/auth/refresh_session_usecase.dart';
import '../../domain/usecases/auth/restore_session_usecase.dart';
import '../../domain/usecases/notifications/add_notification_usecase.dart';
import '../../domain/usecases/notifications/load_inbox_usecase.dart';
import '../../domain/usecases/notifications/mark_all_notifications_read_usecase.dart';
import '../../domain/usecases/notifications/mark_notification_read_usecase.dart';
import '../../domain/usecases/notifications/sync_badge_usecase.dart';
import '../../domain/usecases/push/send_test_notification_usecase.dart';
import '../../domain/usecases/push/set_topic_subscription_usecase.dart';
import '../../domain/usecases/push/start_push_usecase.dart';
import 'auth/auth_controller.dart';

/// Composition root: satu-satunya tempat yang memilih implementasi konkret.
///
/// Inilah titik tegaknya Dependency Inversion — seluruh berkas lain (controller,
/// page, use case) hanya menyebut kontrak di `domain/`. Mengganti Firebase
/// dengan backend sendiri cukup mengubah nilai di berkas ini.
///
/// Provider di bawah dibagi dua kelompok: *dependency* (implementasi konkret) dan
/// *use case* (satu provider per aksi bisnis, supaya mudah di-override di test).

/// Apakah Firebase berhasil diinisialisasi.
///
/// Di-override di `main()` dengan hasil `bootstrapFirebase()`. Nilai default
/// `false` membuat test dan mode tanpa `google-services.json` memakai
/// [MockAuthRepository], sehingga tidak ada platform channel yang tersentuh.
final Provider<bool> firebaseReadyProvider = Provider<bool>((ref) => false);

/// Penyimpanan kunci-nilai untuk kotak masuk (bukan rahasia).
final Provider<KeyValueStore> keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => PrefsKeyValueStore(),
);

final Provider<SessionRepository> sessionRepositoryProvider =
    Provider<SessionRepository>((ref) => SecureSessionRepository());

/// Memilih sumber autentikasi sesuai kesiapan Firebase.
///
/// - Firebase siap → [FirebaseAuthRepository] (login sungguhan ke Firebase Auth)
/// - Firebase tidak siap → [MockAuthRepository] (demo offline, dipakai test)
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
  if (ref.watch(firebaseReadyProvider)) {
    return FirebaseAuthRepository();
  }
  return const MockAuthRepository();
});

/// Klien API yang sudah membawa interceptor refresh.
///
/// Saat sesi tidak bisa dipulihkan, `AuthController.forceLogout` dipanggil
/// sehingga guard route langsung melempar pengguna ke `/login`.
final Provider<Dio> apiClientProvider = Provider<Dio>((ref) {
  return buildApiClient(
    sessions: ref.watch(sessionRepositoryProvider),
    auth: ref.watch(authRepositoryProvider),
    onSessionExpired: () =>
        ref.read(authControllerProvider.notifier).forceLogout(),
  );
});

final Provider<DeviceRepository> deviceRepositoryProvider =
    Provider<DeviceRepository>(
  (ref) => HttpDeviceRepository(ref.watch(apiClientProvider)),
);

final Provider<PushMessaging> pushMessagingProvider = Provider<PushMessaging>(
  (ref) => FcmPushMessaging(),
);

final Provider<NotificationInboxRepository> inboxRepositoryProvider =
    Provider<NotificationInboxRepository>(
  (ref) => SharedPrefsInboxRepository(store: ref.watch(keyValueStoreProvider)),
);

final Provider<AppBadge> appBadgeProvider = Provider<AppBadge>(
  (ref) => const LauncherBadge(),
);

// ---------------------------------------------------------------------------
// Use case. Satu provider per aksi bisnis; meng-override satu provider cukup
// untuk mengganti perilaku di test tanpa menyentuh controller.
// ---------------------------------------------------------------------------

final Provider<SyncBadgeUseCase> syncBadgeUseCaseProvider =
    Provider<SyncBadgeUseCase>(
  (ref) => SyncBadgeUseCase(ref.watch(appBadgeProvider)),
);

final Provider<LoadInboxUseCase> loadInboxUseCaseProvider =
    Provider<LoadInboxUseCase>(
  (ref) => LoadInboxUseCase(
    ref.watch(inboxRepositoryProvider),
    ref.watch(syncBadgeUseCaseProvider),
  ),
);

final Provider<AddNotificationUseCase> addNotificationUseCaseProvider =
    Provider<AddNotificationUseCase>(
  (ref) => AddNotificationUseCase(
    ref.watch(inboxRepositoryProvider),
    ref.watch(syncBadgeUseCaseProvider),
  ),
);

final Provider<MarkNotificationReadUseCase> markNotificationReadUseCaseProvider =
    Provider<MarkNotificationReadUseCase>(
  (ref) => MarkNotificationReadUseCase(
    ref.watch(inboxRepositoryProvider),
    ref.watch(syncBadgeUseCaseProvider),
  ),
);

final Provider<MarkAllNotificationsReadUseCase>
    markAllNotificationsReadUseCaseProvider =
    Provider<MarkAllNotificationsReadUseCase>(
  (ref) => MarkAllNotificationsReadUseCase(
    ref.watch(inboxRepositoryProvider),
    ref.watch(syncBadgeUseCaseProvider),
  ),
);

final Provider<LoginUseCase> loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
  ),
);

final Provider<RestoreSessionUseCase> restoreSessionUseCaseProvider =
    Provider<RestoreSessionUseCase>(
  (ref) => RestoreSessionUseCase(ref.watch(sessionRepositoryProvider)),
);

final Provider<RefreshSessionUseCase> refreshSessionUseCaseProvider =
    Provider<RefreshSessionUseCase>(
  (ref) => RefreshSessionUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
  ),
);

final Provider<LogoutUseCase> logoutUseCaseProvider = Provider<LogoutUseCase>(
  (ref) => LogoutUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(deviceRepositoryProvider),
    ref.watch(pushMessagingProvider),
  ),
);

final Provider<StartPushUseCase> startPushUseCaseProvider =
    Provider<StartPushUseCase>(
  (ref) => StartPushUseCase(
    ref.watch(pushMessagingProvider),
    ref.watch(deviceRepositoryProvider),
  ),
);

final Provider<SendTestNotificationUseCase> sendTestNotificationUseCaseProvider =
    Provider<SendTestNotificationUseCase>(
  (ref) => SendTestNotificationUseCase(
    ref.watch(pushMessagingProvider),
    ref.watch(addNotificationUseCaseProvider),
  ),
);

final Provider<SetTopicSubscriptionUseCase> setTopicSubscriptionUseCaseProvider =
    Provider<SetTopicSubscriptionUseCase>(
  (ref) => SetTopicSubscriptionUseCase(ref.watch(pushMessagingProvider)),
);
