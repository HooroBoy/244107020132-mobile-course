import 'package:campusnotif/data/datasources/key_value_store.dart';
import 'package:campusnotif/data/errors/firebase_auth_messages.dart';
import 'package:campusnotif/data/mappers/app_notification_mapper.dart';
import 'package:campusnotif/data/messaging/firebase_bootstrap.dart';
import 'package:campusnotif/data/repositories/shared_prefs_inbox_repository.dart';
import 'package:campusnotif/domain/entities/app_notification.dart';
import 'package:campusnotif/domain/entities/auth_session.dart';
import 'package:campusnotif/domain/entities/notification_inbox.dart';
import 'package:campusnotif/domain/repositories/app_badge.dart';
import 'package:campusnotif/domain/repositories/session_repository.dart';
import 'package:campusnotif/main.dart';
import 'package:campusnotif/presentation/providers/dependencies.dart';
import 'package:campusnotif/presentation/providers/notifications/notification_controller.dart';
import 'package:campusnotif/presentation/utils/relative_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification _item(String id) => AppNotification.create(
      messageId: id,
      title: 'Judul $id',
      body: 'Isi $id',
      route: '/pengumuman/$id',
    );

/// Badge palsu: mencatat setiap angka yang dipasang.
class RecordingBadge implements AppBadge {
  final List<int> counts = <int>[];

  @override
  Future<void> setCount(int count) async => counts.add(count);
}

class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({this.access, this.refresh, this.email});

  String? access;
  String? refresh;
  String? email;

  @override
  Future<AuthSession?> read() async {
    if (access == null) return null;
    return AuthSession(access: access!, refresh: refresh ?? '', email: email);
  }

  @override
  Future<void> save(AuthSession session) async {
    access = session.access;
    refresh = session.refresh;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

void main() {
  group('AppNotification', () {
    test('id diambil dari messageId bila ada', () {
      final AppNotification item = AppNotification.create(
        messageId: 'm1',
        title: 'Judul',
        body: 'Isi',
        route: '/pengumuman/1',
      );

      expect(item.id, 'm1');
      expect(item.title, 'Judul');
      expect(item.route, '/pengumuman/1');
    });

    test('tanpa messageId, id dibentuk dari waktu + rute', () {
      final AppNotification item = AppNotification.create(
        title: 'Judul',
        body: 'Isi',
        route: '/pengumuman/2',
        receivedAt: DateTime(2026, 11, 2, 10),
      );

      expect(item.id, contains('/pengumuman/2'));
      expect(item.id, isNot(isEmpty));
    });

    test('judul kosong memakai judul pengganti', () {
      final AppNotification item = AppNotification.create(
        title: '   ',
        body: 'Isi',
        route: '/pengumuman/3',
      );

      expect(item.title, AppNotification.fallbackTitle);
    });

    test('judul dan isi dipangkas spasi tepinya', () {
      final AppNotification item = AppNotification.create(
        title: '  Judul  ',
        body: '  Isi  ',
        route: '/pengumuman/4',
      );

      expect(item.title, 'Judul');
      expect(item.body, 'Isi');
    });

    test('serialisasi bolak-balik mempertahankan isi', () {
      final AppNotification item = _item('m9');
      final AppNotification? restored =
          appNotificationFromJson(appNotificationToJson(item));

      expect(restored, isNotNull);
      expect(restored!.id, item.id);
      expect(restored.title, item.title);
      expect(restored.body, item.body);
      expect(restored.route, item.route);
      expect(restored.receivedAt, item.receivedAt);
    });
  });

  group('NotificationInbox', () {
    test('entri baru masuk di urutan teratas', () {
      final List<AppNotification> next =
          NotificationInbox.withAdded(<AppNotification>[_item('lama')], _item('baru'));

      expect(next.map((AppNotification e) => e.id), <String>['baru', 'lama']);
    });

    test('id yang sama diganti, bukan diduplikasi', () {
      final List<AppNotification> next = NotificationInbox.withAdded(
        <AppNotification>[_item('m1'), _item('m2')],
        _item('m2'),
      );

      expect(next.length, 2);
      expect(next.first.id, 'm2');
    });

    test('without menghapus satu entri', () {
      final List<AppNotification> next = NotificationInbox.without(
        <AppNotification>[_item('m1'), _item('m2')],
        'm1',
      );

      expect(next.map((AppNotification e) => e.id), <String>['m2']);
    });

    test('jumlah entri dibatasi maxEntries', () {
      List<AppNotification> items = <AppNotification>[];
      for (int i = 0; i < NotificationInbox.maxEntries + 5; i++) {
        items = NotificationInbox.withAdded(items, _item('m$i'));
      }

      expect(items.length, NotificationInbox.maxEntries);
      expect(items.first.id, 'm${NotificationInbox.maxEntries + 4}');
    });
  });

  group('SharedPrefsInboxRepository', () {
    test('belum ada data -> daftar kosong', () async {
      final SharedPrefsInboxRepository repo =
          SharedPrefsInboxRepository(store: InMemoryKeyValueStore());

      expect(await repo.readAll(), isEmpty);
    });

    test('writeAll lalu readAll mengembalikan entri yang sama', () async {
      final SharedPrefsInboxRepository repo =
          SharedPrefsInboxRepository(store: InMemoryKeyValueStore());

      await repo.writeAll(<AppNotification>[_item('m1'), _item('m2')]);
      final List<AppNotification> items = await repo.readAll();

      expect(items.map((AppNotification e) => e.id), <String>['m1', 'm2']);
    });

    test('isi rusak diperlakukan sebagai kotak masuk kosong', () async {
      final SharedPrefsInboxRepository repo = SharedPrefsInboxRepository(
        store: InMemoryKeyValueStore(<String, String>{
          SharedPrefsInboxRepository.storageKey: 'bukan-json',
        }),
      );

      expect(await repo.readAll(), isEmpty);
    });

    test('satu entri korup dilewati, entri lain tetap terbaca', () async {
      final SharedPrefsInboxRepository repo = SharedPrefsInboxRepository(
        store: InMemoryKeyValueStore(<String, String>{
          SharedPrefsInboxRepository.storageKey: '[{"title":"tanpa id"},'
              '{"id":"ok","route":"/pengumuman/1","title":"T","body":"B",'
              '"received_at":"2026-11-02T10:00:00.000"}]',
        }),
      );

      final List<AppNotification> items = await repo.readAll();

      expect(items.single.id, 'ok');
      expect(items.single.title, 'T');
    });
  });

  group('NotificationController', () {
    ProviderContainer makeContainer(RecordingBadge badges) {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          appBadgeProvider.overrideWithValue(badges),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('add menambah entri dan menaikkan badge', () async {
      final RecordingBadge badges = RecordingBadge();
      final ProviderContainer container = makeContainer(badges);
      final NotificationController center =
          container.read(notificationsProvider.notifier);

      await center.add(_item('m1'));
      await center.add(_item('m2'));

      expect(container.read(notificationsProvider).length, 2);
      expect(badges.counts.last, 2, reason: 'badge = jumlah belum dibaca');
    });

    test('markRead menghapus entri dan menurunkan badge', () async {
      final RecordingBadge badges = RecordingBadge();
      final ProviderContainer container = makeContainer(badges);
      final NotificationController center =
          container.read(notificationsProvider.notifier);

      await center.add(_item('m1'));
      await center.add(_item('m2'));
      await center.markRead('m2');

      expect(
        container.read(notificationsProvider).map((AppNotification e) => e.id),
        <String>['m1'],
      );
      expect(badges.counts.last, 1);
    });

    test('markAllRead mengosongkan daftar dan badge', () async {
      final RecordingBadge badges = RecordingBadge();
      final ProviderContainer container = makeContainer(badges);
      final NotificationController center =
          container.read(notificationsProvider.notifier);

      await center.add(_item('m1'));
      await center.add(_item('m2'));
      await center.markAllRead();

      expect(container.read(notificationsProvider), isEmpty);
      expect(badges.counts.last, 0);
    });

    test('reload membaca entri yang ditulis handler background', () async {
      final InMemoryKeyValueStore kv = InMemoryKeyValueStore();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(kv),
          appBadgeProvider.overrideWithValue(RecordingBadge()),
        ],
      );
      addTearDown(container.dispose);

      // Ditulis "dari luar" (isolate background) sebelum UI membacanya.
      final SharedPrefsInboxRepository repo =
          SharedPrefsInboxRepository(store: kv);
      await repo.writeAll(
        NotificationInbox.withAdded(await repo.readAll(), _item('bg1')),
      );

      final NotificationController center =
          container.read(notificationsProvider.notifier);
      await center.reload();

      expect(container.read(notificationsProvider).single.id, 'bg1');
    });

    test('reload menyusul entri baru meski daftar sudah terisi', () async {
      // Regresi: entri yang ditulis handler background saat aplikasi tidak
      // berjalan harus muncul setelah aplikasi kembali aktif. Tanpa reload,
      // daftar di memori tetap basi walau penyimpanan sudah bertambah.
      final InMemoryKeyValueStore kv = InMemoryKeyValueStore();
      final RecordingBadge badges = RecordingBadge();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(kv),
          appBadgeProvider.overrideWithValue(badges),
        ],
      );
      addTearDown(container.dispose);

      final NotificationController center =
          container.read(notificationsProvider.notifier);
      await center.add(_item('fg1'));
      expect(container.read(notificationsProvider).length, 1);

      // Ditulis proses lain selagi aplikasi di background.
      final SharedPrefsInboxRepository repo =
          SharedPrefsInboxRepository(store: kv);
      await repo.writeAll(
        NotificationInbox.withAdded(await repo.readAll(), _item('bg2')),
      );
      expect(
        container.read(notificationsProvider).length,
        1,
        reason: 'state di memori belum tahu ada entri baru',
      );

      await center.reload();

      expect(
        container.read(notificationsProvider).map((AppNotification e) => e.id),
        <String>['bg2', 'fg1'],
      );
      expect(badges.counts.last, 2, reason: 'badge ikut menyesuaikan');
    });
  });

  group('relativeTime', () {
    final DateTime now = DateTime(2026, 11, 2, 12);

    test('kurang dari semenit -> baru saja', () {
      expect(
        relativeTime(now.subtract(const Duration(seconds: 30)), now: now),
        'baru saja',
      );
    });

    test('menit, jam, dan hari', () {
      expect(
        relativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5 mnt lalu',
      );
      expect(
        relativeTime(now.subtract(const Duration(hours: 3)), now: now),
        '3 jam lalu',
      );
      expect(
        relativeTime(now.subtract(const Duration(days: 2)), now: now),
        '2 hr lalu',
      );
    });

    test('lebih dari sepekan memakai tanggal', () {
      expect(relativeTime(DateTime(2026, 10, 1, 8), now: now), '01/10/2026');
    });

    test('waktu di masa depan dianggap baru saja', () {
      expect(
        relativeTime(now.add(const Duration(minutes: 5)), now: now),
        'baru saja',
      );
    });
  });

  group('authMessageFor', () {
    test('kode dikenal menjadi pesan yang bisa dibaca', () {
      expect(authMessageFor('wrong-password', null), 'Kata sandi salah.');
      expect(authMessageFor('invalid-credential', null),
          'Email atau kata sandi tidak valid.');
      expect(authMessageFor('too-many-requests', null), contains('Terlalu banyak'));
    });

    test('kode tak dikenal memakai detail bila ada', () {
      expect(authMessageFor('kode-aneh', 'server sibuk'),
          'Login gagal: server sibuk');
    });

    test('kode tak dikenal tanpa detail', () {
      expect(authMessageFor('kode-aneh', null), 'Login gagal. Coba lagi.');
    });
  });

  testWidgets('notifikasi yang dibaca hilang dari daftar dan badge berkurang',
      (WidgetTester tester) async {
    final InMemoryKeyValueStore kv = InMemoryKeyValueStore();
    final SharedPrefsInboxRepository repo = SharedPrefsInboxRepository(store: kv);

    // Dua notifikasi belum dibaca, seolah diterima sebelum aplikasi dibuka.
    await repo.writeAll(<AppNotification>[
      AppNotification.create(
        messageId: 'm1',
        title: 'Judul A',
        body: 'Isi A',
        route: '/pengumuman/1',
      ),
      AppNotification.create(
        messageId: 'm2',
        title: 'Judul B',
        body: 'Isi B',
        route: '/pengumuman/2',
      ),
    ]);

    final RecordingBadge badges = RecordingBadge();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(
            FakeSessionRepository(
              access: 'mock-access-for-mhs@polinema.ac.id',
              refresh: 'mock-refresh-for-mhs@polinema.ac.id',
              email: 'mhs@polinema.ac.id',
            ),
          ),
          keyValueStoreProvider.overrideWithValue(kv),
          appBadgeProvider.overrideWithValue(badges),
        ],
        child: const CampusNotifyApp(
          firebase: FirebaseBootstrap.notConfigured('test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Angka pada ikon lonceng = jumlah notifikasi belum dibaca.
    expect(find.text('2'), findsOneWidget);
    expect(badges.counts.last, 2);

    // Pembaca layar harus mendengar "Notifikasi (2 belum dibaca)", bukan "2".
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pump();
    expect(find.byTooltip('Notifikasi (2 belum dibaca)'), findsOneWidget);
    expect(
      find.bySemanticsLabel('2'),
      findsNothing,
      reason: 'angka badge tidak boleh menjadi label semantik tersendiri',
    );
    semantics.dispose();

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Judul A'), findsOneWidget);
    expect(find.text('Judul B'), findsOneWidget);

    // Membaca notifikasi B: entri dihapus lalu rutenya dibuka.
    await tester.tap(find.text('Judul B'));
    await tester.pumpAndSettle();

    expect(find.text('id: 2'), findsOneWidget);
    expect(badges.counts.last, 1);

    // Kembali ke daftar: B sudah hilang, A masih ada.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Judul A'), findsOneWidget);
    expect(find.text('Judul B'), findsNothing);
  });
}
