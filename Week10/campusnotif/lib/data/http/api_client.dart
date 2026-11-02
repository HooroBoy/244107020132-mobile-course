import 'package:dio/dio.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/session_repository.dart';

/// Base URL API kampus. Untuk demo dipakai domain contoh; ganti saat backend
/// nyata tersedia. Jangan pernah menaruh token/secret di sini.
const String kApiBaseUrl = 'https://example-campus-api.test';

/// Penanda di [RequestOptions.extra] agar satu request hanya diulang sekali.
const String _retryFlag = 'auth_retried';

/// Membangun [Dio] dengan dua perilaku wajib:
///
/// 1. setiap request otomatis membawa `Authorization: Bearer <access>`;
/// 2. respons 401 memicu **satu** kali tukar refresh token lalu request diulang;
///    bila refresh ikut mati, sesi dibersihkan dan pengguna dipaksa login ulang.
///
/// Dependensinya abstraksi domain ([SessionRepository], [AuthRepository]),
/// sehingga klien ini tidak peduli token disimpan di secure storage atau di
/// memori saat test.
Dio buildApiClient({
  required SessionRepository sessions,
  required AuthRepository auth,
  required Future<void> Function() onSessionExpired,
  String baseUrl = kApiBaseUrl,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Header yang sudah diset pemanggil tidak ditimpa.
        if (options.headers['Authorization'] == null) {
          final AuthSession? session = await sessions.read();
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.access}';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final bool isUnauthorized = error.response?.statusCode == 401;
        final bool alreadyRetried =
            error.requestOptions.extra[_retryFlag] == true;

        if (!isUnauthorized || alreadyRetried) {
          return handler.next(error);
        }

        final AuthSession? session = await sessions.read();
        if (session == null || session.refresh.isEmpty) {
          await sessions.clear();
          await onSessionExpired();
          return handler.next(error);
        }

        try {
          final String renewed = await auth.refresh(session.refresh);
          // Refresh token lama tetap dipakai; hanya access yang diperbarui.
          await sessions.save(session.copyWith(access: renewed));

          final RequestOptions retryOptions = error.requestOptions
            ..headers['Authorization'] = 'Bearer $renewed'
            ..extra[_retryFlag] = true;

          final Response<dynamic> retried =
              await dio.fetch<dynamic>(retryOptions);
          return handler.resolve(retried);
        } on Object {
          // Refresh token mati -> tidak ada jalan pulih selain login ulang.
          await sessions.clear();
          await onSessionExpired();
          return handler.next(error);
        }
      },
    ),
  );

  return dio;
}
