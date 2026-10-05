import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../local/db.dart';
import '../remote/post.dart';

class PostRepository {
  PostRepository({Dio? dio, Future<Database> Function()? openDb})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://jsonplaceholder.typicode.com',
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          ),
      _openDb = openDb ?? openNotesDb;

  final Dio _dio;
  final Future<Database> Function() _openDb;

  /// Membaca cache lokal tanpa melakukan permintaan jaringan.
  Future<List<Post>> readCachedPosts() async {
    final db = await _openDb();
    final rows = await db.query('cached_posts', orderBy: 'id ASC');
    return rows.map((row) {
      final payload = jsonDecode(row['payload'] as String);
      return Post.fromJson(Map<String, dynamic>.from(payload as Map));
    }).toList();
  }

  /// Mengambil posts terbaru dan mengganti cache secara atomik.
  Future<List<Post>> fetchAndCache() async {
    final response = await _dio.get<List<dynamic>>('/posts');
    final posts = (response.data ?? const <dynamic>[])
        .map((item) => Post.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    final db = await _openDb();
    final cachedAt = DateTime.now().toIso8601String();
    await db.transaction((transaction) async {
      await transaction.delete('cached_posts');
      final batch = transaction.batch();
      for (final post in posts) {
        batch.insert('cached_posts', {
          'id': post.id,
          'payload': jsonEncode(post.toJson()),
          'cached_at': cachedAt,
        });
      }
      await batch.commit(noResult: true);
    });
    return posts;
  }
}
