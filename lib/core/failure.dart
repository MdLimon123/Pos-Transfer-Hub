import 'dart:io';

import 'package:dio/dio.dart';

/// The picked file cannot be uploaded (missing, empty, unreadable...).
class InvalidFileException implements Exception {
  const InvalidFileException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The connection ended before all bytes arrived.
class IncompleteTransferException implements Exception {
  const IncompleteTransferException();
}

/// A user-presentable description of what went wrong.
class Failure {
  const Failure(this.message, {this.isNetwork = false, this.isAuth = false});

  final String message;

  /// Transient connectivity problem: worth retrying / resuming automatically.
  final bool isNetwork;

  /// 401/403: the token is no longer valid.
  final bool isAuth;

  static Failure from(Object error) {
    if (error is Failure) return error;
    if (error is InvalidFileException) return Failure(error.message);
    if (error is IncompleteTransferException) {
      return const Failure('The connection dropped before the transfer finished.',
          isNetwork: true);
    }
    if (error is FileSystemException) {
      return Failure(_fileSystemMessage(error));
    }
    if (error is DioException) return _fromDio(error);
    return const Failure('Something went wrong. Please try again.');
  }

  static Failure _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const Failure(
            'The network is too slow or the server did not respond in time.',
            isNetwork: true);
      case DioExceptionType.connectionError:
        return const Failure(
            'Cannot reach the server. Check your internet connection.',
            isNetwork: true);
      case DioExceptionType.cancel:
        return const Failure('Canceled.');
      case DioExceptionType.badCertificate:
        return const Failure('The server certificate could not be verified.');
      case DioExceptionType.badResponse:
        return _fromStatus(e.response?.statusCode, e.response?.data);
      case DioExceptionType.unknown:
        final inner = e.error;
        if (inner is FileSystemException) {
          return Failure(_fileSystemMessage(inner));
        }
        if (inner is IOException) {
          return const Failure('The connection was interrupted.',
              isNetwork: true);
        }
        if (inner is InvalidFileException) return Failure(inner.message);
        if (inner is IncompleteTransferException) {
          return from(inner);
        }
        return const Failure('Something went wrong. Please try again.');
    }
  }

  static Failure _fromStatus(int? status, Object? body) {
    final serverMessage = serverMessageOf(body);
    switch (status) {
      case 401:
      case 403:
        return const Failure('Your session has expired. Please sign in again.',
            isAuth: true);
      case 404:
        return const Failure('The file no longer exists on the server.');
      case 413:
        return const Failure('The server rejected the file because it is too large.');
      case 415:
      case 422:
        return Failure(serverMessage ?? 'The server does not accept this file.');
      case 408:
      case 429:
      case 502:
      case 503:
      case 504:
        return Failure('The server is busy (error $status). Please retry shortly.',
            isNetwork: true);
    }
    if (status != null && status >= 500) {
      return Failure('Server error ($status). Please try again later.');
    }
    return Failure(serverMessage ?? 'The request was rejected (error $status).');
  }

  static String _fileSystemMessage(FileSystemException e) {
    final code = e.osError?.errorCode;
    if (code == 28) return 'Not enough free storage space on this device.';
    if (code == 2) return 'The file could not be found on this device.';
    return 'A storage error occurred: ${e.osError?.message ?? e.message}';
  }

  /// Pulls `error` / `message` out of the mock API's JSON error bodies.
  static String? serverMessageOf(Object? body) {
    if (body is Map) {
      final m = body['error'] ?? body['message'];
      if (m is String && m.isNotEmpty) return m;
    }
    return null;
  }
}
