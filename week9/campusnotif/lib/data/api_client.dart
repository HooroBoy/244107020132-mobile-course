import 'package:dio/dio.dart';

import 'auth_repository.dart';
import 'token_store.dart';

/// Base URL API kampus. Untuk demo dipakai domain contoh; ganti saat backend
/// nyata tersedia. Jangan pernah menaruh token/secret di sini.
const String kApiBaseUrl = 'https://example-campus-api.test';

/// Penanda di [RequestOptions.extra] agar satu request hanya diulang sekali.
const String _retryFlag = 'auth_retried';

/// Membangun [Dio] dengan dua perilaku wajib:
///
/// 1. setiap request otomatis membawa `Authorization: Bearer <access>`;
/// 2. respons 401 memicu **satu** kali tukar refresh token lalu request
///    diulang; bila refresh ikut mati, sesi dibersihkan dan pengguna dipaksa
///    login ulang.
///
/// Tanpa [onSessionExpired], refresh yang gagal hanya akan menghasilkan 401
/// berulang dan pengguna terjebak di layar kosong.
Dio buildApiClient({
  required TokenStore store,
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
          final access = await store.readAccess();
          if (access != null) {
            options.headers['Authorization'] = 'Bearer $access';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final isUnauthorized = error.response?.statusCode == 401;
        final alreadyRetried = error.requestOptions.extra[_retryFlag] == true;

        if (!isUnauthorized || alreadyRetried) {
          return handler.next(error);
        }

        final refreshToken = await store.readRefresh();
        if (refreshToken == null || refreshToken.isEmpty) {
          await store.clear();
          await onSessionExpired();
          return handler.next(error);
        }

        try {
          final renewed = await auth.refresh(refreshToken);
          // Refresh token lama tetap dipakai; hanya access yang diperbarui.
          await store.save(access: renewed, refresh: refreshToken);

          final retryOptions = error.requestOptions
            ..headers['Authorization'] = 'Bearer $renewed'
            ..extra[_retryFlag] = true;

          final retried = await dio.fetch<dynamic>(retryOptions);
          return handler.resolve(retried);
        } on Object {
          // Refresh token mati -> tidak ada jalan pulih selain login ulang.
          await store.clear();
          await onSessionExpired();
          return handler.next(error);
        }
      },
    ),
  );

  return dio;
}
