import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config.dart';
import '../../core/failure.dart';

class TokenInfo {
  const TokenInfo({this.user, this.expiry});

  final String? user;
  final DateTime? expiry;

  bool get expired => expiry != null && DateTime.now().isAfter(expiry!);

  static TokenInfo? parse(String token) {
    try {
      final payload = token.split('.').first;
      final json = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))));
      if (json is! Map) return null;
      final exp = json['exp'];
      return TokenInfo(
        user: json['user'] as String?,
        expiry: exp is int ? DateTime.fromMillisecondsSinceEpoch(exp * 1000) : null,
      );
    } catch (_) {
      return null;
    }
  }
}

class AuthRepository {
  AuthRepository({FlutterSecureStorage? storage, Dio? dio})
      : _storage = storage ?? const FlutterSecureStorage(),
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ));

  static const _tokenKey = 'auth_token';

  final FlutterSecureStorage _storage;
  final Dio _dio;

  String? _token;
  String? get token => _token;

  /// Called by the API client when the server answers 401/403.
  void Function()? onUnauthorized;

  Future<String?> restore() async {
    try {
      final saved = await _storage.read(key: _tokenKey);
      if (saved == null) return null;
      if (TokenInfo.parse(saved)?.expired ?? false) {
        await clear();
        return null;
      }
      return _token = saved;
    } catch (_) {
      return null;
    }
  }

  Future<String> login(String username, String password) async {
    try {
      final res = await _dio.post<dynamic>(
        '/token',
        data: {'username': username, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final data = res.data;
      final token = data is Map ? (data['token'] ?? data['access_token']) : null;
      if (token is! String || token.isEmpty) {
        throw const Failure('The server did not return a token.');
      }
      await saveToken(token);
      return token;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Failure(Failure.serverMessageOf(e.response?.data) ??
            'Invalid username or password.');
      }
      throw Failure.from(e);
    }
  }

  Future<void> saveToken(String token) async {
    _token = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_){}
  }

  Future<void> clear() async {
    _token = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }
}
