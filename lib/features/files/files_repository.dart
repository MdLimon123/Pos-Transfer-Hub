import 'package:dio/dio.dart';

import '../../core/failure.dart';
import '../transfers/models/remote_file.dart';

class FilesRepository {
  FilesRepository(this._dio);
  final Dio _dio;

  Future<List<RemoteFile>> list() async {
    try {
      final res = await _dio.get<dynamic>('/get');
      final files = (res.data is Map ? res.data['files'] : null) as List? ?? [];
      return files
          .map((e) => RemoteFile.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => (b.uploadedAt ?? DateTime(0)).compareTo(a.uploadedAt ?? DateTime(0)));
    } on DioException catch (e) {
      throw Failure.from(e);
    }
  }

  Future<void> delete(String name) async {
    try {
      await _dio.delete<dynamic>('/delete', queryParameters: {'file': name});
    } on DioException catch (e) {
      throw Failure.from(e);
    }
  }
}
