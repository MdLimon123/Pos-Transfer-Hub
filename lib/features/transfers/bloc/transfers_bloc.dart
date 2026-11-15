// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config.dart';
import '../../../core/failure.dart';
import '../../../core/foreground_service.dart';
import '../../../core/notification_service.dart';
import '../../../core/storage_bridge.dart';
import '../data/transfer_service.dart';
import '../data/transfer_store.dart';
import '../models/transfer_task.dart';

part 'transfers_event.dart';
part 'transfers_state.dart';

/// Owns every upload/download for the whole app, independent of any screen.
///
/// Transfers are plain async jobs that keep running while the app is minimised
/// (kept alive in the background by [ForegroundTransferService]). They never
/// emit directly; they report back through private events so that all state
/// changes are serialised through this Bloc.

class TransfersBloc extends Bloc<TransfersEvent, TransfersState> {
  TransfersBloc({
    required TransferService service,
    required TransferStore store,
    required NotificationService notifications,
    required ForegroundTransferService foreground,
    required StorageBridge storage,
  })  : _service = service,
        _store = store,
        _notifications = notifications,
        _foreground = foreground,
        _storage = storage,
        super(const TransfersState()) {
    on<TransfersStarted>(_onStarted);
    on<UploadRequested>(_onUpload);
    on<DownloadRequested>(_onDownload);
    on<TransferPaused>(_onPause);
    on<TransferResumed>(_onResume);
    on<TransferRetried>(_onResume);
    on<TransferCanceled>(_onCancel);
    on<TransferRemoved>(_onRemove);
    on<FinishedTransfersCleared>(_onClearFinished);
    on<ConnectivityChanged>(_onConnectivity);
    on<_Progress>(_onProgress);
    on<_Note>(_onNote);
    on<_Completed>(_onCompleted);
    on<_Failed>(_onFailed);
  }

  final TransferService _service;
  final TransferStore _store;
  final NotificationService _notifications;
  final ForegroundTransferService _foreground;
  final StorageBridge _storage;

  final _tokens = <String, CancelToken>{};
  final _runs = <String, Future<void>>{};
  final _lastNotified = <String, DateTime>{};
  final _lastProgressEvent = <String, DateTime>{};
  bool _online = true;
  int _counter = 0;

  // ------------------------------------------------------------ lifecycle

  Future<void> _onStarted(TransfersStarted event, Emitter<TransfersState> emit) async {
    final saved = await _store.load();
    // The process died while these were running: nothing is running now.
    final tasks = saved.map((t) {
      if (!t.isActive) return t;
      return t.copyWith(
        status: TransferStatus.paused,
        message: 'Interrupted when the app closed. Resume to continue.',
      );
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final t in tasks.where((t) => t.status == TransferStatus.paused)) {
      unawaited(_notifications.showState(t, 'Transfer paused', t.name));
    }
    emit(TransfersState(tasks: tasks, loaded: true));
  }

  @override
  void onChange(Change<TransfersState> change) {
    super.onChange(change);
    final tasks = change.nextState.tasks;
    final pending = tasks.where((t) => t.isActive).length;
    final running = tasks.where((t) => t.status == TransferStatus.running).length;
    unawaited(_foreground.sync(pending: pending, running: running));
    if (change.nextState.loaded) unawaited(_store.save(tasks));
  }

  @override
  Future<void> close() {
    for (final t in _tokens.values) {
      t.cancel('closed');
    }
    return super.close();
  }

  // ------------------------------------------------------------ requests

  void _onUpload(UploadRequested e, Emitter<TransfersState> emit) {
    final task = TransferTask(
      id: _newId(),
      type: TransferType.upload,
      name: e.name,
      createdAt: DateTime.now(),
      sourcePath: e.path,
      totalBytes: e.size,
    );
    emit(_withTask(task));
    _pump(emit);
  }

  void _onDownload(DownloadRequested e, Emitter<TransfersState> emit) {
    final existing = state.downloadOf(e.remoteName);
    if (existing != null && (existing.isActive || existing.status == TransferStatus.paused)) {
      return; // already on its way
    }
    final task = TransferTask(
      id: _newId(),
      type: TransferType.download,
      name: e.displayName,
      createdAt: DateTime.now(),
      remoteName: e.remoteName,
      url: e.url,
      totalBytes: e.size,
    );
    emit(_withTask(task));
    _pump(emit);
  }

  // ------------------------------------------------------------ controls

  void _onPause(TransferPaused e, Emitter<TransfersState> emit) {
    final t = state.byId(e.id);
    if (t == null || !(t.isActive)) return;
    _tokens[e.id]?.cancel('paused');
    _update(emit, e.id, (t) => t.copyWith(status: TransferStatus.paused, clearMessage: true));
    _notifyState(e.id, 'Transfer paused');
    _pump(emit);
  }

  /// Handles both Resume (paused / waiting) and Retry (failed).
  void _onResume(TransfersEvent e, Emitter<TransfersState> emit) {
    final id = e is TransferResumed ? e.id : (e as TransferRetried).id;
    final t = state.byId(id);
    if (t == null || t.status == TransferStatus.running || t.status == TransferStatus.queued) {
      return;
    }
    if (t.status == TransferStatus.completed || t.status == TransferStatus.canceled) return;
    _update(
      emit,
      id,
      (t) => t.copyWith(
        status: TransferStatus.queued,
        clearMessage: true,
        // Multipart uploads cannot continue mid-file, so they restart.
        transferredBytes: t.isUpload ? 0 : t.transferredBytes,
      ),
    );
    _pump(emit);
  }

  void _onCancel(TransferCanceled e, Emitter<TransfersState> emit) {
    final t = state.byId(e.id);
    if (t == null || t.isFinished) return;
    _tokens[e.id]?.cancel('canceled');
    if (!t.isUpload) unawaited(_service.deletePartial(e.id));
    _update(emit, e.id, (t) => t.copyWith(status: TransferStatus.canceled, clearMessage: true));
    _notifyState(e.id, 'Transfer canceled');
    _pump(emit);
  }

  void _onRemove(TransferRemoved e, Emitter<TransfersState> emit) {
    final t = state.byId(e.id);
    if (t == null) return;
    _tokens[e.id]?.cancel('removed');
    if (!t.isUpload && t.status != TransferStatus.completed) {
      unawaited(_service.deletePartial(e.id));
    }
    unawaited(_notifications.cancelFor(t));
    emit(TransfersState(
      tasks: state.tasks.where((x) => x.id != e.id).toList(),
      loaded: true,
    ));
    _pump(emit);
  }

  void _onClearFinished(FinishedTransfersCleared e, Emitter<TransfersState> emit) {
    for (final t in state.tasks.where((t) => t.isFinished)) {
      unawaited(_notifications.cancelFor(t));
    }
    emit(TransfersState(
      tasks: state.tasks.where((t) => !t.isFinished).toList(),
      loaded: true,
    ));
  }

  void _onConnectivity(ConnectivityChanged e, Emitter<TransfersState> emit) {
    _online = e.online;
    if (!e.online) {
      // Stop burning retries against a dead link; resume when it is back.
      for (final t in state.tasks.where((t) => t.status == TransferStatus.running)) {
        _tokens[t.id]?.cancel('offline');
        _update(
          emit,
          t.id,
          (t) => t.copyWith(
              status: TransferStatus.waitingNetwork, message: 'Waiting for network…'),
        );
        _notifyState(t.id, 'Waiting for network');
      }
    } else {
      for (final t in state.tasks.where((t) => t.status == TransferStatus.waitingNetwork)) {
        _update(emit, t.id, (t) => t.copyWith(status: TransferStatus.queued, clearMessage: true));
      }
      _pump(emit);
    }
  }

  // ------------------------------------------------------------ scheduling

  /// Starts queued transfers while there is spare concurrency.
  void _pump(Emitter<TransfersState> emit) {
    if (!_online) return;
    var running = state.tasks.where((t) => t.status == TransferStatus.running).length;
    final queued = state.tasks.where((t) => t.status == TransferStatus.queued).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final t in queued) {
      if (running >= AppConfig.maxConcurrentTransfers) break;
      running++;
      _update(emit, t.id, (t) => t.copyWith(status: TransferStatus.running, clearMessage: true));
      _start(state.byId(t.id)!);
    }
  }

  void _start(TransferTask task) {
    final previous = _runs[task.id];
    final run = () async {
      // Wait for a just-paused run to release the partial file.
      if (previous != null) await previous.catchError((_) {});
      await _execute(task);
    }();
    _runs[task.id] = run;
    run.whenComplete(() {
      if (identical(_runs[task.id], run)) _runs.remove(task.id);
    });
  }

  Future<void> _execute(TransferTask task) async {
    final token = CancelToken();
    _tokens[task.id] = token;
    final maxRetries =
        task.isUpload ? AppConfig.uploadRetries : AppConfig.downloadRetries;

    try {
      for (var attempt = 0;; attempt++) {
        if (token.isCancelled) return;
        try {
          if (task.isUpload) {
            final remote = await _service.upload(
              path: task.sourcePath!,
              fileName: task.name,
              cancelToken: token,
              onProgress: (d, t) => _report(task.id, d, t),
            );
            if (!token.isCancelled) add(_Completed(task.id, remoteName: remote.name));
          } else {
            final file = await _service.download(
              taskId: task.id,
              url: task.url!,
              cancelToken: token,
              onProgress: (d, t) => _report(task.id, d, t),
            );
            if (token.isCancelled) return;
            final location = await _storage.saveToDownloads(file.path, task.name);
            await _service.deletePartial(task.id);
            add(_Completed(task.id, savedLocation: location));
          }
          return;
        } catch (e) {
          if (token.isCancelled || (e is DioException && CancelToken.isCancel(e))) return;
          final failure = Failure.from(e);
          if (failure.isNetwork && attempt < maxRetries) {
            final wait = Duration(seconds: 2 << attempt);
            add(_Note(task.id,
                'Connection problem. Retrying in ${wait.inSeconds}s (${attempt + 1}/$maxRetries)…'));
            await Future.any([Future<void>.delayed(wait), token.whenCancel]);
            continue;
          }
          add(_Failed(task.id, failure));
          return;
        }
      }
    } finally {
      if (identical(_tokens[task.id], token)) _tokens.remove(task.id);
    }
  }

  /// Throttles progress to ~5 events/second so the UI and bloc stay light.
  void _report(String id, int done, int total) {
    final now = DateTime.now();
    final last = _lastProgressEvent[id];
    if (last != null && now.difference(last).inMilliseconds < 200 && done < total) return;
    _lastProgressEvent[id] = now;
    add(_Progress(id, done, total));
  }

  // ------------------------------------------------------------ internal events

  void _onProgress(_Progress e, Emitter<TransfersState> emit) {
    final t = state.byId(e.id);
    if (t == null || t.status != TransferStatus.running) return;
    _update(
      emit,
      e.id,
      (t) => t.copyWith(
        transferredBytes: e.done,
        totalBytes: e.total > 0 ? e.total : t.totalBytes,
        clearMessage: true,
      ),
    );
    final now = DateTime.now();
    final last = _lastNotified[e.id];
    if (last == null || now.difference(last).inMilliseconds >= 800) {
      _lastNotified[e.id] = now;
      unawaited(_notifications.showProgress(state.byId(e.id)!));
    }
  }

  void _onNote(_Note e, Emitter<TransfersState> emit) {
    final t = state.byId(e.id);
    if (t == null || t.status != TransferStatus.running) return;
    _update(emit, e.id, (t) => t.copyWith(message: e.message));
  }

  void _onCompleted(_Completed e, Emitter<TransfersState> emit) {
    final t = state.byId(e.id);
    if (t == null || t.isFinished) return;
    _update(
      emit,
      e.id,
      (t) => t.copyWith(
        status: TransferStatus.completed,
        transferredBytes: t.totalBytes > 0 ? t.totalBytes : t.transferredBytes,
        remoteName: e.remoteName,
        savedLocation: e.savedLocation,
        clearMessage: true,
      ),
    );
    unawaited(_notifications.showCompleted(state.byId(e.id)!));
    _pump(emit);
  }

  void _onFailed(_Failed e, Emitter<TransfersState> emit) {
    final t = state.byId(e.id);
    if (t == null || t.isFinished || t.status == TransferStatus.paused) return;

    if (e.failure.isNetwork && !_online) {
      _update(
        emit,
        e.id,
        (t) => t.copyWith(
            status: TransferStatus.waitingNetwork, message: 'Waiting for network…'),
      );
      _notifyState(e.id, 'Waiting for network');
    } else {
      _update(
        emit,
        e.id,
        (t) => t.copyWith(status: TransferStatus.failed, message: e.failure.message),
      );
      _notifyState(e.id, '${t.isUpload ? 'Upload' : 'Download'} failed', e.failure.message);
    }
    _pump(emit);
  }

  // ------------------------------------------------------------ helpers

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}${_counter++}';

  TransfersState _withTask(TransferTask t) =>
      TransfersState(tasks: [t, ...state.tasks], loaded: true);

  void _update(
    Emitter<TransfersState> emit,
    String id,
    TransferTask Function(TransferTask) change,
  ) {
    emit(TransfersState(
      tasks: [for (final t in state.tasks) t.id == id ? change(t) : t],
      loaded: true,
    ));
  }

  void _notifyState(String id, String title, [String? body]) {
    final t = state.byId(id);
    if (t == null) return;
    unawaited(_notifications.showState(t, title, body ?? t.name));
  }
}
