import 'dart:async';

import 'package:campusnotif/data/datasources/key_value_store.dart';
import 'package:campusnotif/domain/entities/app_notification.dart';
import 'package:campusnotif/domain/repositories/device_repository.dart';
import 'package:campusnotif/domain/repositories/push_messaging.dart';
import 'package:campusnotif/presentation/providers/dependencies.dart';
import 'package:campusnotif/presentation/providers/notifications/notification_controller.dart';
import 'package:campusnotif/presentation/providers/push/push_controller.dart';
import 'package:campusnotif/presentation/providers/push/push_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pengganti FCM: seluruh kejadian (token, pesan, ketukan) dipicu manual dari
/// test, tanpa plugin atau platform channel.
class FakePushMessaging implements PushMessaging {
  final StreamController<String> tokenController =
      StreamController<String>.broadcast();
  final StreamController<AppNotification> foreground =
      StreamController<AppNotification>.broadcast();
  final StreamController<AppNotification> opened =
      StreamController<AppNotification>.broadcast();
  final StreamController<String> taps = StreamController<String>.broadcast();

  final List<AppNotification> banners = <AppNotification>[];
  int prepareCount = 0;
  int subscribeCount = 0;
  int unsubscribeCount = 0;
  bool permissionGranted = true;
  String? token = 'token-uji';

  @override
  Future<void> prepare() async => prepareCount++;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<String?> currentToken() async => token;

  @override
  Stream<String> get tokenRefresh => tokenController.stream;

  @override
  Stream<AppNotification> get foregroundMessages => foreground.stream;

  @override
  Stream<AppNotification> get openedMessages => opened.stream;

  @override
  Stream<String> get bannerTaps => taps.stream;

  @override
  Future<AppNotification?> initialMessage() async => null;

  @override
  Future<void> subscribeTopic(String topic) async => subscribeCount++;

  @override
  Future<void> unsubscribeTopic(String topic) async => unsubscribeCount++;

  @override
  Future<void> showBanner(AppNotification notification) async =>
      banners.add(notification);

  Future<void> close() async {
    await tokenController.close();
    await foreground.close();
    await opened.close();
    await taps.close();
  }
}

/// Pengganti backend `POST/DELETE /devices`.
class FakeDeviceRepository implements DeviceRepository {
  FakeDeviceRepository({this.acceptRegistration = true});

  bool acceptRegistration;
  final List<String> registered = <String>[];
  final List<String> unregistered = <String>[];

  @override
  Future<bool> register({required String token}) async {
    registered.add(token);
    return acceptRegistration;
  }

  @override
  Future<bool> unregister({required String token}) async {
    unregistered.add(token);
    return true;
  }
}

ProviderContainer _container({
  required FakePushMessaging push,
  FakeDeviceRepository? devices,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      pushMessagingProvider.overrideWithValue(push),
      deviceRepositoryProvider
          .overrideWithValue(devices ?? FakeDeviceRepository()),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('PushState.copyWith', () {
    test('tanpa argumen, seluruh nilai dipertahankan', () {
      const PushState state = PushState(
        started: true,
        permissionGranted: true,
        token: 'token-uji',
        registeredOnBackend: true,
        subscribedTopic: true,
        lastRoute: '/pengumuman/3',
        note: 'catatan',
      );

      final PushState copy = state.copyWith();

      expect(copy.started, isTrue);
      expect(copy.token, 'token-uji');
      expect(copy.lastRoute, '/pengumuman/3');
      expect(copy.note, 'catatan');
    });

    test('null pada token mengosongkan token lama', () {
      const PushState state = PushState(token: 'token-uji');

      final PushState copy = state.copyWith(token: null);

      expect(copy.token, isNull);
      expect(copy.maskedToken, '-');
    });

    test('null pada note mengosongkan catatan lama (regresi)', () {
      // Bug lama: copyWith(note: null) dianggap "tidak diisi" sehingga catatan
      // error tetap tampil walau masalahnya sudah hilang.
      const PushState state = PushState(note: 'FCM gagal disiapkan');

      expect(state.copyWith(note: null).note, isNull);
      expect(state.copyWith().note, 'FCM gagal disiapkan');
    });

    test('null pada lastRoute mengosongkan rute terakhir', () {
      const PushState state = PushState(lastRoute: '/pengumuman/9');

      expect(state.copyWith(lastRoute: null).lastRoute, isNull);
    });

    test('maskedToken tidak membocorkan token utuh', () {
      const PushState state = PushState(token: 'abcdefghijklmnopqrstuvwxyz');

      expect(state.maskedToken, isNot(contains('mnop')));
      expect(state.maskedToken, contains('••••'));
    });
  });

  group('PushController', () {
    test('start menyiapkan kanal, mendaftarkan token, dan berlangganan topik',
        () async {
      final FakePushMessaging push = FakePushMessaging();
      addTearDown(push.close);
      final FakeDeviceRepository devices = FakeDeviceRepository();
      final ProviderContainer container =
          _container(push: push, devices: devices);

      await container.read(pushProvider.notifier).start(firebaseReady: true);
      final PushState state = container.read(pushProvider);

      expect(push.prepareCount, 1, reason: 'kanal dibuat sebelum pesan datang');
      expect(devices.registered, <String>['token-uji']);
      expect(push.subscribeCount, 1);
      expect(state.started, isTrue);
      expect(state.token, 'token-uji');
      expect(state.permissionGranted, isTrue);
      expect(state.registeredOnBackend, isTrue);
      expect(state.subscribedTopic, isTrue);
      expect(state.note, isNull);
    });

    test('token baru dari FCM dilaporkan ulang ke backend', () async {
      final FakePushMessaging push = FakePushMessaging();
      addTearDown(push.close);
      final FakeDeviceRepository devices = FakeDeviceRepository();
      final ProviderContainer container =
          _container(push: push, devices: devices);

      await container.read(pushProvider.notifier).start(firebaseReady: true);

      push.tokenController.add('token-baru');
      for (int i = 0; i < 50 && devices.registered.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(devices.registered, <String>['token-uji', 'token-baru']);
    });

    test('catatan muncul bila backend belum menerima token', () async {
      final FakePushMessaging push = FakePushMessaging();
      addTearDown(push.close);
      final ProviderContainer container = _container(
        push: push,
        devices: FakeDeviceRepository(acceptRegistration: false),
      );

      await container.read(pushProvider.notifier).start(firebaseReady: true);
      final PushState state = container.read(pushProvider);

      expect(state.registeredOnBackend, isFalse);
      expect(state.note, contains('POST /devices'));
      expect(state.token, 'token-uji', reason: 'token tetap ada di perangkat');
    });

    test('izin ditolak menghasilkan catatan, bukan kegagalan senyap', () async {
      final FakePushMessaging push = FakePushMessaging()
        ..permissionGranted = false;
      addTearDown(push.close);
      final ProviderContainer container = _container(push: push);

      await container.read(pushProvider.notifier).start(firebaseReady: true);

      expect(container.read(pushProvider).permissionGranted, isFalse);
      expect(container.read(pushProvider).note, contains('Izin notifikasi'));
    });

    test('tanpa Firebase, start hanya menulis catatan dan tidak menyentuh FCM',
        () async {
      final FakePushMessaging push = FakePushMessaging();
      addTearDown(push.close);
      final ProviderContainer container = _container(push: push);

      await container
          .read(pushProvider.notifier)
          .start(firebaseReady: false, firebaseNote: 'Firebase belum siap');

      expect(container.read(pushProvider).started, isFalse);
      expect(container.read(pushProvider).note, 'Firebase belum siap');
      expect(push.prepareCount, 0);
    });

    test('pesan foreground masuk ke kotak masuk dan memunculkan banner',
        () async {
      final FakePushMessaging push = FakePushMessaging();
      addTearDown(push.close);
      final ProviderContainer container = _container(push: push);

      await container.read(pushProvider.notifier).start(firebaseReady: true);

      push.foreground.add(
        AppNotification.create(
          messageId: 'm1',
          title: 'Jadwal berubah',
          body: 'Pindah ruang',
          route: '/pengumuman/1',
        ),
      );

      for (int i = 0;
          i < 50 && container.read(notificationsProvider).isEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(container.read(notificationsProvider).single.id, 'm1');
      expect(push.banners.length, 1);
    });

    test('detach menghentikan langganan topik dan mengosongkan state', () async {
      final FakePushMessaging push = FakePushMessaging();
      addTearDown(push.close);
      final ProviderContainer container = _container(push: push);

      await container.read(pushProvider.notifier).start(firebaseReady: true);
      await container.read(pushProvider.notifier).detach();
      final PushState state = container.read(pushProvider);

      expect(push.unsubscribeCount, 1);
      expect(state.started, isFalse);
      expect(state.token, isNull);
      expect(state.registeredOnBackend, isFalse);
      expect(state.subscribedTopic, isFalse);
      expect(state.note, isNull);
    });

    test('setelah detach, pesan foreground tidak lagi dicatat', () async {
      final FakePushMessaging push = FakePushMessaging();
      addTearDown(push.close);
      final ProviderContainer container = _container(push: push);

      await container.read(pushProvider.notifier).start(firebaseReady: true);
      await container.read(pushProvider.notifier).detach();

      push.foreground.add(
        AppNotification.create(
          messageId: 'm2',
          title: 'Setelah logout',
          body: 'Tidak boleh masuk',
          route: '/pengumuman/2',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(container.read(notificationsProvider), isEmpty);
      expect(push.banners, isEmpty);
    });

    test('start berulang tidak memasang listener ganda, tetapi boleh setelah '
        'detach', () async {
      final FakePushMessaging push = FakePushMessaging();
      addTearDown(push.close);
      final ProviderContainer container = _container(push: push);

      await container.read(pushProvider.notifier).start(firebaseReady: true);
      await container.read(pushProvider.notifier).start(firebaseReady: true);
      expect(push.prepareCount, 1, reason: 'panggilan kedua diabaikan');

      await container.read(pushProvider.notifier).detach();
      await container.read(pushProvider.notifier).start(firebaseReady: true);

      expect(push.prepareCount, 2, reason: 'login berikutnya memasang ulang');
      expect(push.subscribeCount, 2);
      expect(container.read(pushProvider).started, isTrue);
    });
  });
}
