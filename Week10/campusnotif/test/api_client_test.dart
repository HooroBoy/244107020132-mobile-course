import 'dart:convert';
import 'dart:typed_data';

import 'package:campusnotif/data/http/api_client.dart';
import 'package:campusnotif/domain/entities/auth_session.dart';
import 'package:campusnotif/domain/errors/auth_exception.dart';
import 'package:campusnotif/domain/repositories/auth_repository.dart';
import 'package:campusnotif/domain/repositories/session_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Penyimpanan sesi di memori (tanpa secure storage sungguhan).
class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({this.access, this.refresh});

  String? access;
  String? refresh;
  int clearCount = 0;

  @override
  Future<AuthSession?> read() async {
    if (access == null) return null;
    return AuthSession(access: access!, refresh: refresh ?? '');
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
    clearCount++;
  }
}

/// Adapter HTTP palsu: mengembalikan 401 untuk access token lama dan 200 untuk
/// access token hasil refresh. Tidak ada jaringan sungguhan yang dipakai.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter({required this.validToken});

  final String validToken;
  final List<String> seenAuthHeaders = <String>[];
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    final String auth = '${options.headers['Authorization']}';
    seenAuthHeaders.add(auth);

    if (auth == 'Bearer $validToken') {
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{'ok': true}),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'error': 'token expired'}),
      401,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Repository yang selalu gagal refresh (refresh token sudah mati).
class DeadRefreshRepository implements AuthRepository {
  const DeadRefreshRepository();

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    throw const AuthException('tidak dipakai');
  }

  @override
  Future<String> refresh(String refreshToken) async {
    throw const AuthException('Refresh token ditolak server');
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  test('401 -> refresh sekali -> request diulang dan sukses', () async {
    final store =
        FakeSessionRepository(access: 'access-basi', refresh: 'refresh-ok');
    final adapter = ScriptedAdapter(validToken: 'access-baru');
    var sessionExpiredCalls = 0;

    // Repository yang mengembalikan access token yang diterima adapter.
    final dio = buildApiClient(
      sessions: store,
      auth: _RenewingRepository('access-baru'),
      onSessionExpired: () async => sessionExpiredCalls++,
    )..httpClientAdapter = adapter;

    final Response<dynamic> response = await dio.get<dynamic>('/pengumuman');

    expect(response.statusCode, 200);
    expect(adapter.callCount, 2, reason: 'satu request awal + satu retry');
    expect(adapter.seenAuthHeaders.first, 'Bearer access-basi');
    expect(adapter.seenAuthHeaders.last, 'Bearer access-baru');
    expect(store.access, 'access-baru');
    expect(store.refresh, 'refresh-ok', reason: 'refresh token tidak berubah');
    expect(store.clearCount, 0);
    expect(sessionExpiredCalls, 0);
  });

  test('refresh mati -> sesi dibersihkan, tidak ada retry berulang', () async {
    final store =
        FakeSessionRepository(access: 'access-basi', refresh: 'refresh-mati');
    final adapter = ScriptedAdapter(validToken: 'tidak-pernah-dipakai');
    var sessionExpiredCalls = 0;

    final dio = buildApiClient(
      sessions: store,
      auth: const DeadRefreshRepository(),
      onSessionExpired: () async => sessionExpiredCalls++,
    )..httpClientAdapter = adapter;

    await expectLater(
      dio.get<dynamic>('/pengumuman'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.callCount, 1, reason: 'tidak ada retry karena refresh gagal');
    expect(store.clearCount, 1);
    expect(store.access, isNull);
    expect(sessionExpiredCalls, 1);
  });

  test('tanpa refresh token tersimpan -> langsung bersihkan sesi', () async {
    final store = FakeSessionRepository(access: 'access-basi');
    final adapter = ScriptedAdapter(validToken: 'apa-saja');
    var sessionExpiredCalls = 0;

    final dio = buildApiClient(
      sessions: store,
      auth: _RenewingRepository('apa-saja'),
      onSessionExpired: () async => sessionExpiredCalls++,
    )..httpClientAdapter = adapter;

    await expectLater(
      dio.get<dynamic>('/pengumuman'),
      throwsA(isA<DioException>()),
    );

    expect(store.clearCount, 1);
    expect(sessionExpiredCalls, 1);
  });
}

class _RenewingRepository implements AuthRepository {
  const _RenewingRepository(this.newAccess);

  final String newAccess;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    throw const AuthException('tidak dipakai');
  }

  @override
  Future<String> refresh(String refreshToken) async => newAccess;

  @override
  Future<void> signOut() async {}
}
