import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/mahasiswa.dart';

class ApiService {
  late final Dio _dio;

  // URL dapat dioverride saat menjalankan aplikasi, misalnya:
  // flutter run --dart-define=API_BASE_URL=http://192.168.0.4:8000/api
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Default untuk HP Android fisik. HP dan komputer harus berada di
      // jaringan yang sama, dan server harus bind ke 0.0.0.0:8000.
      return 'http://192.168.0.4:8000/api';
    }

    return 'http://127.0.0.1:8000/api';
  }

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Logging Interceptor untuk mempermudah pengecekan request dan response di konsol
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[DIO LOG]: $obj'),
      ),
    );
  }

  // 1. Ambil Semua Data Mahasiswa (GET)
  Future<List<Mahasiswa>> getMahasiswa() async {
    try {
      final response = await _dio.get('/mahasiswa');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List dataList = response.data['data'];
        return dataList.map((item) => Mahasiswa.fromJson(item)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 2. Tambah Data Mahasiswa Baru (POST)
  Future<Mahasiswa> createMahasiswa(Mahasiswa mahasiswa) async {
    try {
      final response = await _dio.post('/mahasiswa', data: mahasiswa.toJson());
      return Mahasiswa.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 3. Ubah Data Mahasiswa (PUT)
  Future<Mahasiswa> updateMahasiswa(int id, Mahasiswa mahasiswa) async {
    try {
      final response = await _dio.put(
        '/mahasiswa/$id',
        data: mahasiswa.toJson(),
      );
      return Mahasiswa.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 4. Hapus Data Mahasiswa (DELETE)
  Future<void> deleteMahasiswa(int id) async {
    try {
      await _dio.delete('/mahasiswa/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Penanganan pesan error yang informatif
  String _handleError(DioException error) {
    if (error.response != null && error.response?.data != null) {
      final data = error.response?.data;
      if (data is Map && data.containsKey('message')) {
        return data['message'].toString();
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return 'Koneksi ke server API timeout ($baseUrl). Pastikan server '
            'aktif dan HP terhubung ke jaringan yang sama dengan komputer.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server API ($baseUrl). Pastikan '
            'backend berjalan di 0.0.0.0:8000 dan firewall mengizinkan port '
            '8000.';
      case DioExceptionType.badCertificate:
        return 'Sertifikat server API tidak valid.';
      case DioExceptionType.cancel:
        return 'Permintaan ke server API dibatalkan.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    return error.message ?? 'Terjadi kegagalan komunikasi dengan server';
  }
}
