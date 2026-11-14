import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/failure.dart';
import '../models/remote_file.dart';

typedef BytesProgress = void Function(int done, int total);

/// Network layer for moving bytes. Knows nothing about Bloc or notifications.
class TransferService {
  TransferService(this._dio);

  final Dio _dio;

  /// multipart/form-data POST of [path]. The file is streamed from disk, so
  /// memory use stays flat even for very large files.
  Future<RemoteFile> upload({
    required String path,
    required String fileName,
    required CancelToken cancelToken,
    required BytesProgress onProgress,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const InvalidFileException(
          'The selected file is no longer available. Please pick it again.');
    }
    if (await file.length() == 0) {
      throw const InvalidFileException('The selected file is empty.');
    }
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: fileName),
    });
    final res = await _dio.post<dynamic>(
      '/upload',
      data: form,
      cancelToken: cancelToken,
      onSendProgress: onProgress,
    );
    final data = res.data;
    if (data is Map && data['success'] == true && data['file'] is Map) {
      return RemoteFile.fromJson(Map<String, dynamic>.from(data['file'] as Map));
    }
    throw Failure(Failure.serverMessageOf(data) ?? 'The server rejected the upload.');
  }

  /// Location of the partial file for a download task.
  Future<File> partialFile(String taskId) async {
    final dir = await getApplicationSupportDirectory();
    final downloads = Directory(p.join(dir.path, 'downloads'));
    await downloads.create(recursive: true);
    return File(p.join(downloads.path, '$taskId.part'));
  }

  Future<void> deletePartial(String taskId) async {
    try {
      final f = await partialFile(taskId);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Resumable download. If a partial file exists we ask for `Range: bytes=N-`
  /// and append; if the server ignores the range (HTTP 200) we start over.
  /// Returns the completed temporary file.
  Future<File> download({
    required String taskId,
    required String url,
    required CancelToken cancelToken,
    required BytesProgress onProgress,
  }) async {
    final file = await partialFile(taskId);
    var offset = await file.exists() ? await file.length() : 0;

    final res = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: offset > 0 ? {'Range': 'bytes=$offset-'} : null,
        validateStatus: (s) => s == 200 || s == 206 || s == 416,
      ),
    );

    if (res.statusCode == 416) {
      // Requested range starts at/after the end: we already have everything.
      onProgress(offset, offset);
      return file;
    }

    final resumed = res.statusCode == 206 && offset > 0;
    if (!resumed) offset = 0;
    final total = _totalSize(res, offset);

    final sink = file.openWrite(mode: resumed ? FileMode.append : FileMode.write);
    var received = offset;
    try {
      await for (final chunk in res.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    if (total > 0 && received < total) throw const IncompleteTransferException();
    onProgress(received, received);
    return file;
  }

  int _totalSize(Response<ResponseBody> res, int offset) {
    final range = res.headers.value('content-range'); // bytes 100-999/1000
    if (range != null) {
      final total = int.tryParse(range.split('/').last);
      if (total != null) return total;
    }
    final length = int.tryParse(res.headers.value('content-length') ?? '') ?? 0;
    return length > 0 ? length + offset : 0;
  }
}
