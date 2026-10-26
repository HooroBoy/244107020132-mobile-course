import 'package:dio/dio.dart';

/// Mendaftarkan token perangkat ke backend agar server bisa mengirim notifikasi
/// personal ke pengguna ini.
///
/// Kontrak endpoint (didokumentasikan di README):
/// `POST /devices` dengan body `{"fcm_token": "...", "platform": "android"}`.
/// Request wajib membawa header Authorization dari [Dio] interceptor.
class DeviceRepository {
  const DeviceRepository(this._dio);

  final Dio _dio;

  /// Mengembalikan `true` bila backend menerima token.
  ///
  /// Kegagalan jaringan tidak boleh mematikan aplikasi: token tetap tersimpan
  /// di sisi Firebase, hanya laporan ke backend yang tertunda.
  Future<bool> registerDevice({
    required String token,
    required String platform,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/devices',
        data: <String, String>{'fcm_token': token, 'platform': platform},
      );
      final int? status = response.statusCode;
      return status != null && status >= 200 && status < 300;
    } on DioException {
      return false;
    }
  }

  /// Melepas token saat logout agar pengguna tidak lagi menerima notifikasi
  /// personal di perangkat yang sudah keluar.
  Future<bool> unregisterDevice({required String token}) async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        '/devices',
        data: <String, String>{'fcm_token': token},
      );
      final int? status = response.statusCode;
      return status != null && status >= 200 && status < 300;
    } on DioException {
      return false;
    }
  }
}
