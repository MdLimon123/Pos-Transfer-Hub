import 'package:flutter/services.dart';
import 'package:mime/mime.dart';

import 'failure.dart';


class StorageBridge {
  static const _channel = MethodChannel('com.possaas.transferhub/storage');

  static String mimeOf(String fileName) =>
      lookupMimeType(fileName) ?? 'application/octet-stream';

  /// Copies [sourcePath] to Downloads/TransferHub and returns its location

  Future<String> saveToDownloads(String sourcePath, String fileName) async {
    final allowed = await _channel.invokeMethod<bool>('ensureStoragePermission') ?? false;
    if (!allowed) {
      throw const Failure('Storage permission is required to save downloads.');
    }
    try {
      final location = await _channel.invokeMethod<String>('saveToDownloads', {
        'source': sourcePath,
        'name': fileName,
        'mime': mimeOf(fileName),
      });
      return location!;
    } on PlatformException catch (e) {
      throw Failure('Could not save the file to Downloads: ${e.message}');
    }
  }


  Future<bool> open(String location, String fileName) async {
    try {
      await _channel.invokeMethod('openFile', {
        'location': location,
        'mime': mimeOf(fileName),
      });
      return true;
    } on PlatformException {
      return false;
    }
  }
}
