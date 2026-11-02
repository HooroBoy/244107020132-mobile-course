import 'package:campusnotif/data/device_repository.dart';
import 'package:campusnotif/data/notification_store.dart';
import 'package:campusnotif/messaging/push_service.dart';
import 'package:campusnotif/providers/notification_providers.dart';
import 'package:campusnotif/providers/push_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `PushService` palsu: tidak menyentuh Firebase maupun plugin notifikasi.
///
/// `super()` aman karena `_messaging` diselesaikan malas di [PushService], jadi
/// `FirebaseMessaging.instance` (yang memanggil `Firebase.app()`) tidak pernah
/// disentuh saat objek dibuat.
class FakePushService extends PushService {
  /// Callback terakhir yang dipasang `start()`, dipakai test untuk meniru
  /// `onTokenRefresh` yang datang belakangan.
  Future<void> Function(String token)? onToken;

  int subscribeCount = 0;
  int unsubscribeCount = 0;

  @override
  Future<void> initLocalNotifications() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> initFcmToken({
    required Future<void> Function(String token) onToken,
  }) async {
    this.onToken = onToken;
    await onToken('fcm-token-uji');
  }

  @override
  Future<void> subscribeCampusTopic() async => subscribeCount++;

  @override
  Future<void> unsubscribeCampusTopic() async => unsubscribeCount++;

  @override
  Future<void> listenMessages({
    required void Function(String route) onRoute,
    required Future<void> Function(AppNotification notification) onNotification,
    required Future<void> Function(String? messageId, String route) onOpened,
  }) async {}

  @override
  Future<void> showLocalNotification({
    required String title,
    required String body,
    required String route,
  }) async {}
}

/// `DeviceRepository` palsu yang merekam token tanpa jaringan.
class FakeDeviceRepository extends DeviceRepository {
  FakeDeviceRepository() : super(Dio());

  bool registerResult = true;
  final List<String> registered = <String>[];
  final List<String> unregistered = <String>[];

  @override
  Future<bool> registerDevice({
    required String token,
    required String platform,
  }) async {
    registered.add(token);
    return registerResult;
  }

  @override
  Future<bool> unregisterDevice({required String token}) async {
    unregistered.add(token);
    return true;
  }
}

void main() {
  group('PushState.copyWith', () {
    const PushState penuh = PushState(
      started: true,
      permissionGranted: true,
      token: 'token-panjang-sekali-1234',
      registeredOnBackend: true,
      subscribedTopic: true,
      lastRoute: '/pengumuman/9',
      note: 'catatan lama',
    );

    test('tanpa argumen mempertahankan seluruh nilai', () {
      final PushState hasil = penuh.copyWith();

      expect(hasil.started, isTrue);
      expect(hasil.permissionGranted, isTrue);
      expect(hasil.token, penuh.token);
      expect(hasil.registeredOnBackend, isTrue);
      expect(hasil.subscribedTopic, isTrue);
      expect(hasil.lastRoute, '/pengumuman/9');
      expect(hasil.note, 'catatan lama');
    });

    test('null mengosongkan note, bukan mempertahankannya', () {
      final PushState hasil = penuh.copyWith(note: null);

      expect(hasil.note, isNull);
      expect(hasil.token, penuh.token, reason: 'field lain tidak berubah');
      expect(hasil.lastRoute, '/pengumuman/9');
    });

    test('null mengosongkan token dan lastRoute', () {
      final PushState hasil = penuh.copyWith(token: null, lastRoute: null);

      expect(hasil.token, isNull);
      expect(hasil.lastRoute, isNull);
      expect(hasil.note, 'catatan lama');
    });

    test('nilai baru menggantikan nilai lama', () {
      final PushState hasil = penuh.copyWith(
        note: 'catatan baru',
        subscribedTopic: false,
      );

      expect(hasil.note, 'catatan baru');
      expect(hasil.subscribedTopic, isFalse);
    });

    test('maskedToken tidak membocorkan token utuh', () {
      expect(penuh.maskedToken, isNot(penuh.token));
      expect(penuh.maskedToken, contains('••••'));
      expect(const PushState().maskedToken, '-', reason: 'belum ada token');
    });
  });

  group('PushController', () {
    late ProviderContainer container;
    late FakePushService service;
    late FakeDeviceRepository devices;

    setUp(() {
      service = FakePushService();
      devices = FakeDeviceRepository();
      container = ProviderContainer(
        overrides: [
          pushServiceProvider.overrideWithValue(service),
          deviceRepositoryProvider.overrideWithValue(devices),
          // Tanpa ini kotak masuk menyentuh shared_preferences.
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );
      addTearDown(container.dispose);
    });

    test('start melaporkan token dan berlangganan topik', () async {
      final PushController push = container.read(pushProvider.notifier);

      await push.start(firebaseReady: true);

      final PushState state = container.read(pushProvider);
      expect(devices.registered, <String>['fcm-token-uji']);
      expect(state.token, 'fcm-token-uji');
      expect(state.permissionGranted, isTrue);
      expect(state.subscribedTopic, isTrue);
      expect(service.subscribeCount, 1);
      expect(state.registeredOnBackend, isTrue);
      expect(state.note, isNull);
    });

    test('catatan error hilang setelah pelaporan token berhasil', () async {
      devices.registerResult = false;
      final PushController push = container.read(pushProvider.notifier);
      await push.start(firebaseReady: true);

      expect(
        container.read(pushProvider).note,
        isNotNull,
        reason: 'POST /devices gagal harus dilaporkan',
      );

      // Token berubah (mis. lewat onTokenRefresh) dan laporan diterima.
      devices.registerResult = true;
      await service.onToken!('fcm-token-baru');

      final PushState state = container.read(pushProvider);
      expect(state.token, 'fcm-token-baru');
      expect(state.registeredOnBackend, isTrue);
      expect(
        state.note,
        isNull,
        reason: 'catatan lama harus bisa dikosongkan lewat copyWith',
      );
    });

    test('detach melepas perangkat, topik, dan mengosongkan status', () async {
      final PushController push = container.read(pushProvider.notifier);
      await push.start(firebaseReady: true);

      await push.detach();

      final PushState state = container.read(pushProvider);
      expect(devices.unregistered, <String>['fcm-token-uji']);
      expect(service.unsubscribeCount, 1);
      expect(state.token, isNull);
      expect(state.registeredOnBackend, isFalse);
      expect(state.subscribedTopic, isFalse);
      expect(state.note, isNull);
      expect(
        state.started,
        isFalse,
        reason: 'start() harus bisa memasang FCM lagi setelah login ulang',
      );
    });

    test('detach tanpa token tidak memanggil backend', () async {
      final PushController push = container.read(pushProvider.notifier);

      await push.detach();

      expect(devices.unregistered, isEmpty);
      expect(service.unsubscribeCount, 0);
    });
  });
}
