import 'package:dio/dio.dart';

import '../features/auth/auth_repository.dart';
import 'config.dart';

/// Single configured [Dio] used by every repository. Adds the bearer token and

Dio createApiClient(AuthRepository auth) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    
    receiveTimeout: const Duration(seconds: 30),
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = auth.token;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    },
    onError: (e, handler) {
      final status = e.response?.statusCode;
      if (status == 401) auth.onUnauthorized?.call();
      handler.next(e);
    },
  ));
  return dio;
}
