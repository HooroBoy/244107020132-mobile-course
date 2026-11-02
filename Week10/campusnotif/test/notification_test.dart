import 'package:campusnotif/data/auth_repository.dart';
import 'package:campusnotif/data/badge_service.dart';
import 'package:campusnotif/data/notification_store.dart';
import 'package:campusnotif/data/relative_time.dart';
import 'package:campusnotif/data/token_store.dart';
import 'package:campusnotif/main.dart';
import 'package:campusnotif/messaging/firebase_bootstrap.dart';
import 'package:campusnotif/providers/auth_provider.dart';
import 'package:campusnotif/providers/notification_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Token store di memori supaya test tidak menyentuh secure storage.
class FakeTokenStore extends TokenStore {
  FakeTokenStore({this.access, this.refresh, this.email});

  String? access;
  String? refresh;
  String? email;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<String?> readEmail() async => email;

  @override
  Future<void> save({
    required String access,
    required String refresh,
    String? email,
  }) async {
    this.access = access;
    this.refresh = refresh;
    if (email != null) this.email = email;
  }

  @override
  Future<bool> hasSession() async => access != null;

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
    email = null;
  }
}

/// Mencatat angka badge yang diminta, tanpa platform channel.
class RecordingBadgeService extends BadgeService {
  RecordingBadgeService();

  final List<int> counts = <int>[];

  @override
  Future<void> setCount(int count) async => counts.add(count);
}

AppNotification _item(String id) => AppNotification.fromMessage(
      messageId: id,
      title: 'Judul $id',
      body: 'Isi $id',
      route: '/pengumuman/$id',
    );

void main() {
  group('AppNotification', () {
    test('id memakai messageId bila tersedia', () {
      expect(_item('m1').id, 'm1');
    });

    test('id dibuat dari waktu + rute bila messageId kosong', () {
      final AppNotification item = AppNotification.fromMessage(
        messageId: '   ',
        title: 'A',
        body: 'B',
        route: '/pengumuman/3',
        receivedAt: DateTime(2026, 1, 2, 3, 4, 5),
      );

      expect(item.id, contains('/pengumuman/3'));
      expect(item.id, isNot(isEmpty));
    });

    test('judul kosong diganti "Pengumuman"', () {
      final AppNotification item = AppNotification.fromMessage(
        title: '  ',
        body: '',
        route: '/',
      );

      expect(item.title, 'Pengumuman');
    });

    test('json bolak-balik menjaga isi', () {
      final AppNotification asli = AppNotification.fromMessage(
        messageId: 'm9',
        title: 'Jadwal berubah',
        body: 'Ruang A2',
        route: '/pengumuman/9',
        receivedAt: DateTime(2026, 3, 4, 5, 6, 7),
      );

      final AppNotification? hasil =
          AppNotification.fromJson(asli.toJson());

      expect(hasil, isNotNull);
      expect(hasil!.id, 'm9');
      expect(hasil.title, 'Jadwal berubah');
      expect(hasil.route, '/pengumuman/9');
      expect(hasil.receivedAt, asli.receivedAt);
    });

    test('json tanpa id/rute diabaikan', () {
      expect(AppNotification.fromJson(<String, dynamic>{}), isNull);
      expect(
        AppNotification.fromJson(<String, dynamic>{'id': 'x'}),
        isNull,
      );
    });
  });

  group('NotificationStore', () {
    test('append menaruh entri terbaru di depan', () async {
      final store = NotificationStore(InMemoryKeyValueStore());

      await store.append(_item('m1'));
      final List<AppNotification> items = await store.append(_item('m2'));

      expect(items.map((AppNotification e) => e.id).toList(), <String>['m2', 'm1']);
    });

    test('append dengan id sama tidak menduplikasi', () async {
      final store = NotificationStore(InMemoryKeyValueStore());

      await store.append(_item('m1'));
      final List<AppNotification> items = await store.append(_item('m1'));

      expect(items.length, 1);
    });

    test('remove membuat notifikasi yang dibaca hilang', () async {
      final store = NotificationStore(InMemoryKeyValueStore());
      await store.append(_item('m1'));
      await store.append(_item('m2'));

      final List<AppNotification> items = await store.remove('m2');

      expect(items.length, 1);
      expect(items.single.id, 'm1');
      // Perubahan ikut tersimpan.
      expect((await store.load()).single.id, 'm1');
    });

    test('clear mengosongkan kotak masuk', () async {
      final store = NotificationStore(InMemoryKeyValueStore());
      await store.append(_item('m1'));

      expect(await store.clear(), isEmpty);
      expect(await store.load(), isEmpty);
    });

    test('data rusak tidak membuat crash', () async {
      final store = NotificationStore(
        InMemoryKeyValueStore(<String, String>{
          NotificationStore.storageKey: 'bukan json',
        }),
      );

      expect(await store.load(), isEmpty);
    });

    test('jumlah entri dibatasi maxEntries', () async {
      final store = NotificationStore(InMemoryKeyValueStore());

      for (int i = 0; i < NotificationStore.maxEntries + 5; i++) {
        await store.append(_item('m$i'));
      }

      expect((await store.load()).length, NotificationStore.maxEntries);
    });
  });

  group('NotificationCenter', () {
    test('add menambah daftar dan memperbarui badge', () async {
      final RecordingBadgeService badges = RecordingBadgeService();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          badgeServiceProvider.overrideWithValue(badges),
        ],
      );
      addTearDown(container.dispose);

      final NotificationCenter center =
          container.read(notificationsProvider.notifier);

      await center.add(_item('m1'));
      await center.add(_item('m2'));

      expect(container.read(notificationsProvider).length, 2);
      expect(badges.counts.last, 2, reason: 'badge = jumlah belum dibaca');
    });

    test('markRead menghapus entri dan menurunkan badge', () async {
      final RecordingBadgeService badges = RecordingBadgeService();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          badgeServiceProvider.overrideWithValue(badges),
        ],
      );
      addTearDown(container.dispose);

      final NotificationCenter center =
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
      final RecordingBadgeService badges = RecordingBadgeService();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          badgeServiceProvider.overrideWithValue(badges),
        ],
      );
      addTearDown(container.dispose);

      final NotificationCenter center =
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
          badgeServiceProvider.overrideWithValue(RecordingBadgeService()),
        ],
      );
      addTearDown(container.dispose);

      // Ditulis "dari luar" (isolate background) sebelum UI membacanya.
      await NotificationStore(kv).append(_item('bg1'));

      final NotificationCenter center =
          container.read(notificationsProvider.notifier);
      await center.reload();

      expect(container.read(notificationsProvider).single.id, 'bg1');
    });

    test('reload menyusul entri baru meski daftar sudah terisi', () async {
      // Regresi: entri yang ditulis handler background saat aplikasi tidak
      // berjalan harus muncul setelah aplikasi kembali aktif. Tanpa reload,
      // daftar di memori tetap basi walau penyimpanan sudah bertambah.
      final InMemoryKeyValueStore kv = InMemoryKeyValueStore();
      final RecordingBadgeService badges = RecordingBadgeService();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(kv),
          badgeServiceProvider.overrideWithValue(badges),
        ],
      );
      addTearDown(container.dispose);

      final NotificationCenter center =
          container.read(notificationsProvider.notifier);
      await center.add(_item('fg1'));
      expect(container.read(notificationsProvider).length, 1);

      // Ditulis proses lain selagi aplikasi di background.
      await NotificationStore(kv).append(_item('bg2'));
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
    final NotificationStore store = NotificationStore(kv);

    // Dua notifikasi belum dibaca, seolah diterima sebelum aplikasi dibuka.
    await store.append(
      AppNotification.fromMessage(
        messageId: 'm1',
        title: 'Judul A',
        body: 'Isi A',
        route: '/pengumuman/1',
      ),
    );
    await store.append(
      AppNotification.fromMessage(
        messageId: 'm2',
        title: 'Judul B',
        body: 'Isi B',
        route: '/pengumuman/2',
      ),
    );

    final RecordingBadgeService badges = RecordingBadgeService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(
            FakeTokenStore(
              access: 'mock-access-for-mhs@polinema.ac.id',
              refresh: 'mock-refresh-for-mhs@polinema.ac.id',
              email: 'mhs@polinema.ac.id',
            ),
          ),
          keyValueStoreProvider.overrideWithValue(kv),
          badgeServiceProvider.overrideWithValue(badges),
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
