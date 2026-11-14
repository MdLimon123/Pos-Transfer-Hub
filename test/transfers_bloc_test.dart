import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_transfer_hub/core/failure.dart';
import 'package:pos_transfer_hub/core/foreground_service.dart';
import 'package:pos_transfer_hub/core/notification_service.dart';
import 'package:pos_transfer_hub/core/storage_bridge.dart';
import 'package:pos_transfer_hub/features/transfers/bloc/transfers_bloc.dart';
import 'package:pos_transfer_hub/features/transfers/data/transfer_service.dart';
import 'package:pos_transfer_hub/features/transfers/data/transfer_store.dart';
import 'package:pos_transfer_hub/features/transfers/models/remote_file.dart';
import 'package:pos_transfer_hub/features/transfers/models/transfer_task.dart';

class FakeNotifications extends NotificationService {
  @override
  Future<void> showProgress(TransferTask t) async {}
  @override
  Future<void> showState(TransferTask t, String title, String body) async {}
  @override
  Future<void> showCompleted(TransferTask t) async {}
  @override
  Future<void> cancelFor(TransferTask t) async {}
}

class FakeForeground extends ForegroundTransferService {
  FakeForeground() : super(FakeNotifications());
  @override
  Future<void> sync({required int pending, required int running}) async {}
}

class FakeStore extends TransferStore {
  @override
  Future<List<TransferTask>> load() async => [];
  @override
  Future<void> save(List<TransferTask> tasks) async {}
}

class FakeStorage extends StorageBridge {
  @override
  Future<String> saveToDownloads(String sourcePath, String fileName) async =>
      'content://downloads/$fileName';
}

/// Transfers finish only when [gate] completes (or fail with [error]).
class FakeTransferService extends TransferService {
  FakeTransferService() : super(Dio());

  Completer<void> gate = Completer<void>();
  Object? error;
  int downloadCalls = 0;

  Future<void> _wait(CancelToken token) async {
    await Future.any([gate.future, token.whenCancel]);
    if (token.isCancelled) {
      throw DioException.requestCancelled(requestOptions: RequestOptions(), reason: 'x');
    }
    if (error != null) throw error!;
  }

  @override
  Future<RemoteFile> upload({
    required String path,
    required String fileName,
    required CancelToken cancelToken,
    required BytesProgress onProgress,
  }) async {
    onProgress(50, 100);
    await _wait(cancelToken);
    onProgress(100, 100);
    return RemoteFile(name: 'srv_$fileName', originalName: fileName, size: 100, url: 'u');
  }

  @override
  Future<File> download({
    required String taskId,
    required String url,
    required CancelToken cancelToken,
    required BytesProgress onProgress,
  }) async {
    downloadCalls++;
    onProgress(40, 100);
    await _wait(cancelToken);
    onProgress(100, 100);
    return File('/tmp/$taskId.part');
  }

  @override
  Future<void> deletePartial(String taskId) async {}
}

DioException _serverError(int status) => DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: RequestOptions(), statusCode: status),
    );

void main() {
  late FakeTransferService service;
  late TransfersBloc bloc;

  setUp(() {
    service = FakeTransferService();
    bloc = TransfersBloc(
      service: service,
      store: FakeStore(),
      notifications: FakeNotifications(),
      foreground: FakeForeground(),
      storage: FakeStorage(),
    )..add(const TransfersStarted());
  });

  tearDown(() => bloc.close());

  Future<TransferTask> settle(bool Function(TransferTask) test) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final match = bloc.state.tasks.where(test);
      if (match.isNotEmpty) return match.first;
    }
    fail('Condition not reached. State: ${bloc.state.tasks}');
  }

  test('upload runs and completes', () async {
    bloc.add(const UploadRequested(path: '/x/a.csv', name: 'a.csv', size: 100));
    final running = await settle((t) => t.status == TransferStatus.running);
    expect(running.isUpload, isTrue);

    service.gate.complete();
    final done = await settle((t) => t.status == TransferStatus.completed);
    expect(done.remoteName, 'srv_a.csv');
    expect(done.progress, 1);
  });

  test('download can be paused and resumed', () async {
    bloc.add(const DownloadRequested(
        remoteName: 'r.bin', displayName: 'r.bin', url: 'http://x/r', size: 100));
    final t = await settle((t) => t.status == TransferStatus.running);

    bloc.add(TransferPaused(t.id));
    await settle((t) => t.status == TransferStatus.paused);

    bloc.add(TransferResumed(t.id));
    await settle((t) => t.status == TransferStatus.running);
    expect(service.downloadCalls, 2, reason: 'resume starts a new ranged request');

    service.gate.complete();
    final done = await settle((t) => t.status == TransferStatus.completed);
    expect(done.savedLocation, 'content://downloads/r.bin');
  });

  test('server error fails with a readable message and can be retried', () async {
    service.error = _serverError(500);
    service.gate.complete();
    bloc.add(const UploadRequested(path: '/x/a.csv', name: 'a.csv', size: 100));
    final failed = await settle((t) => t.status == TransferStatus.failed);
    expect(failed.message, contains('Server error (500)'));

    service.error = null;
    bloc.add(TransferRetried(failed.id));
    await settle((t) => t.status == TransferStatus.completed);
  });

  test('losing the network parks transfers and resumes them when it returns', () async {
    bloc.add(const DownloadRequested(
        remoteName: 'r.bin', displayName: 'r.bin', url: 'http://x/r', size: 100));
    await settle((t) => t.status == TransferStatus.running);

    bloc.add(const ConnectivityChanged(online: false));
    await settle((t) => t.status == TransferStatus.waitingNetwork);

    bloc.add(const ConnectivityChanged(online: true));
    await settle((t) => t.status == TransferStatus.running);
    service.gate.complete();
    await settle((t) => t.status == TransferStatus.completed);
  });

  test('canceled transfers stay canceled', () async {
    bloc.add(const UploadRequested(path: '/x/a.csv', name: 'a.csv', size: 100));
    final t = await settle((t) => t.status == TransferStatus.running);
    bloc.add(TransferCanceled(t.id));
    await settle((t) => t.status == TransferStatus.canceled);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state.byId(t.id)!.status, TransferStatus.canceled);
  });

  group('Failure mapping', () {
    test('timeouts are network problems', () {
      final f = Failure.from(DioException(
          requestOptions: RequestOptions(), type: DioExceptionType.receiveTimeout));
      expect(f.isNetwork, isTrue);
    });
    test('401 means the session expired', () {
      expect(Failure.from(_serverError(401)).isAuth, isTrue);
    });
    test('invalid file is a plain failure', () {
      final f = Failure.from(const InvalidFileException('empty'));
      expect(f.message, 'empty');
      expect(f.isNetwork, isFalse);
    });
  });

  test('TransferTask survives a JSON round trip', () {
    final t = TransferTask(
      id: '1',
      type: TransferType.download,
      name: 'a.png',
      createdAt: DateTime(2026, 11, 14),
      status: TransferStatus.paused,
      totalBytes: 10,
      transferredBytes: 4,
      url: 'u',
    );
    expect(TransferTask.fromJson(t.toJson()), t);
  });
}
