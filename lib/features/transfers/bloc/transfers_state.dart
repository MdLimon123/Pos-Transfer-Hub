part of 'transfers_bloc.dart';

class TransfersState extends Equatable {
  const TransfersState({this.tasks = const [], this.loaded = false});

  /// Newest first.
  final List<TransferTask> tasks;
  final bool loaded;

  Iterable<TransferTask> get active => tasks.where((t) => t.isActive);

  /// Everything the global banner cares about: running, queued, waiting or paused.
  Iterable<TransferTask> get unfinished =>
      tasks.where((t) => t.isActive || t.status == TransferStatus.paused);

  /// Combined progress (0..1) of all unfinished transfers, null if unknown.
  double? get overallProgress {
    var done = 0, total = 0;
    for (final t in unfinished) {
      done += t.transferredBytes;
      total += t.totalBytes;
    }
    return total > 0 ? (done / total).clamp(0.0, 1.0) : null;
  }

  TransferTask? byId(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Latest download of a given server file, if any.
  TransferTask? downloadOf(String remoteName) {
    for (final t in tasks) {
      if (t.type == TransferType.download && t.remoteName == remoteName) return t;
    }
    return null;
  }

  @override
  List<Object?> get props => [tasks, loaded];
}
