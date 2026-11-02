import 'package:dio/dio.dart';

import '../../domain/repositories/device_repository.dart';
import '../platform/platform_name.dart';

/// Mendaftarkan token perangkat ke backend.
///
/// Kontrak endpoint: `POST /devices` dengan body
/// `{"fcm_token": "...", "platform": "android"}` dan `DELETE /devices` dengan
/// body `{"fcm_token": "..."}`. Header Authorization disisipkan interceptor Dio,
/// bukan oleh repository ini.
class HttpDeviceRepository implements DeviceRepository {
  const HttpDeviceRepository(this._dio);

  final Dio _dio;

  @override
  Future<bool> register({required String token}) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/devices',
        data: <String, String>{'fcm_token': token, 'platform': platformName},
      );
      return _isSuccess(response.statusCode);
    } on DioException {
      // Token tetap sah di sisi Firebase; hanya laporan backend yang tertunda.
      return false;
    }
  }

  @override
  Future<bool> unregister({required String token}) async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        '/devices',
        data: <String, String>{'fcm_token': token},
      );
      return _isSuccess(response.statusCode);
    } on DioException {
      return false;
    }
  }

  static bool _isSuccess(int? status) =>
      status != null && status >= 200 && status < 300;
}
