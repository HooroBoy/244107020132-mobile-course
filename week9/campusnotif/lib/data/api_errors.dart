import 'package:dio/dio.dart';

/// Menerjemahkan error teknis menjadi pesan yang layak dibaca pengguna.
///
/// UI tidak boleh menampilkan `DioException` mentah: isinya berisi URL,
/// header, dan kadang token yang ikut tercetak di layar.
String friendlyApiMessage(Object error) {
  if (error is AuthExpiredException) return error.message;

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return 'Koneksi lambat. Coba lagi sebentar.';
      case DioExceptionType.connectionError:
        return 'Tidak ada koneksi internet.';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 401) return 'Sesi berakhir. Silakan login ulang.';
        if (status == 403) return 'Anda tidak punya akses ke data ini.';
        if (status == 404) return 'Data tidak ditemukan.';
        if (status != null && status >= 500) {
          return 'Server sedang bermasalah. Coba lagi nanti.';
        }
        return 'Permintaan ditolak server ($status).';
      case DioExceptionType.cancel:
        return 'Permintaan dibatalkan.';
      case DioExceptionType.badCertificate:
        return 'Sertifikat server tidak valid.';
      case DioExceptionType.unknown:
        return 'Terjadi kesalahan tak terduga.';
    }
  }

  return 'Terjadi kesalahan tak terduga.';
}

/// Sesi tidak bisa dipulihkan: refresh token hilang atau ditolak server.
class AuthExpiredException implements Exception {
  const AuthExpiredException([this.message = 'Sesi berakhir. Silakan login ulang.']);

  final String message;

  @override
  String toString() => message;
}
