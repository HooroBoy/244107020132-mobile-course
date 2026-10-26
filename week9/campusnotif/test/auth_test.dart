import 'package:campusnotif/data/auth_repository.dart';
import 'package:campusnotif/data/token_store.dart';
import 'package:campusnotif/main.dart';
import 'package:campusnotif/messaging/firebase_bootstrap.dart';
import 'package:campusnotif/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Token store palsu: mengganti flutter_secure_storage dengan memori biasa,
/// sehingga test tidak butuh platform channel Android/iOS.
class FakeTokenStore extends TokenStore {
  FakeTokenStore({this.access, this.refresh, this.email});

  String? access;
  String? refresh;
  String? email;
  int clearCount = 0;

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
    clearCount++;
  }
}

Widget _app(FakeTokenStore store) {
  return ProviderScope(
    overrides: [tokenStoreProvider.overrideWithValue(store)],
    // Firebase sengaja tidak siap di test: tidak ada platform channel FCM,
    // sehingga PushController berhenti lebih awal tanpa memanggil Firebase.
    child: const CampusNotifyApp(
      firebase: FirebaseBootstrap.notConfigured('test'),
    ),
  );
}

void main() {
  testWidgets('tanpa sesi, guard route memaksa ke /login', (tester) async {
    await tester.pumpWidget(_app(FakeTokenStore()));
    await tester.pumpAndSettle();

    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Campus Notify'), findsOneWidget);
  });

  testWidgets('dengan sesi tersimpan, langsung masuk beranda', (tester) async {
    final store = FakeTokenStore(
      access: 'mock-access-for-mhs@polinema.ac.id',
      refresh: 'mock-refresh-for-mhs@polinema.ac.id',
      email: 'mhs@polinema.ac.id',
    );

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('Sesi aktif'), findsOneWidget);
    expect(find.text('mhs@polinema.ac.id'), findsOneWidget);
    // Token tidak pernah tampil utuh.
    expect(find.text('mock-access-for-mhs@polinema.ac.id'), findsNothing);
    expect(find.textContaining('••••'), findsOneWidget);
  });

  testWidgets('sesi setengah jadi (tanpa refresh) dibersihkan', (tester) async {
    final store = FakeTokenStore(access: 'mock-access-tanpa-refresh');

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(store.clearCount, 1);
    expect(store.access, isNull);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('login valid menyimpan token lalu pindah ke beranda',
      (tester) async {
    final store = FakeTokenStore();

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'mhs@polinema.ac.id',
    );
    await tester.enterText(find.byType(TextFormField).last, 'rahasia123');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(store.access, 'mock-access-for-mhs@polinema.ac.id');
    expect(store.refresh, 'mock-refresh-for-mhs@polinema.ac.id');
    expect(find.text('Sesi aktif'), findsOneWidget);
  });

  testWidgets('login tidak valid menampilkan pesan error, sesi tetap kosong',
      (tester) async {
    final store = FakeTokenStore();

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'bukan-email');
    await tester.enterText(find.byType(TextFormField).last, '12345');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Format email tidak valid'), findsOneWidget);
    expect(find.text('Minimal 6 karakter'), findsOneWidget);
    expect(store.access, isNull);
  });

  test('refresh berhasil mengganti access, refresh tetap sama', () async {
    final store = FakeTokenStore(
      access: 'mock-access-lama',
      refresh: 'mock-refresh-for-mhs@polinema.ac.id',
      email: 'mhs@polinema.ac.id',
    );
    final container = ProviderContainer(
      overrides: [tokenStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    final bool ok =
        await container.read(authStateProvider.notifier).refreshSession();

    expect(ok, isTrue);
    expect(store.access, startsWith('mock-access-renewed-'));
    expect(store.refresh, 'mock-refresh-for-mhs@polinema.ac.id');
    expect(store.clearCount, 0);
  });

  test('refresh ditolak server -> sesi dibersihkan (paksa login ulang)',
      () async {
    final store = FakeTokenStore(
      access: 'mock-access-lama',
      refresh: 'mock-refresh-revoked',
    );
    final container = ProviderContainer(
      overrides: [tokenStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    final bool ok =
        await container.read(authStateProvider.notifier).refreshSession();

    expect(ok, isFalse);
    expect(store.access, isNull);
    expect(store.clearCount, 1);
    expect(container.read(authStateProvider).value, isNull);
  });

  test('AuthSession.maskedAccess tidak membocorkan token utuh', () {
    const session = AuthSession(
      access: 'mock-access-for-mhs@polinema.ac.id',
      refresh: 'r',
    );

    expect(session.maskedAccess, isNot(contains('polinema')));
    expect(session.maskedAccess, contains('••••'));
  });
}
