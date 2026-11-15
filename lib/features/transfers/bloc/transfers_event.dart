part of 'transfers_bloc.dart';

sealed class TransfersEvent {
  const TransfersEvent();
}


class TransfersStarted extends TransfersEvent {
  const TransfersStarted();
}

class UploadRequested extends TransfersEvent {
  const UploadRequested({required this.path, required this.name, required this.size});
  final String path;
  final String name;
  final int size;
}

class DownloadRequested extends TransfersEvent {
  const DownloadRequested({
    required this.remoteName,
    required this.displayName,
    required this.url,
    required this.size,
  });
  final String remoteName;
  final String displayName;
  final String url;
  final int size;
}

class TransferPaused extends TransfersEvent {
  const TransferPaused(this.id);
  final String id;
}

class TransferResumed extends TransfersEvent {
  const TransferResumed(this.id);
  final String id;
}

class TransferRetried extends TransfersEvent {
  const TransferRetried(this.id);
  final String id;
}

class TransferCanceled extends TransfersEvent {
  const TransferCanceled(this.id);
  final String id;
}

class TransferRemoved extends TransfersEvent {
  const TransferRemoved(this.id);
  final String id;
}

class FinishedTransfersCleared extends TransfersEvent {
  const FinishedTransfersCleared();
}

class ConnectivityChanged extends TransfersEvent {
  const ConnectivityChanged({required this.online});
  final bool online;
}



class _Progress extends TransfersEvent {
  const _Progress(this.id, this.done, this.total);
  final String id;
  final int done;
  final int total;
}

class _Note extends TransfersEvent {
  const _Note(this.id, this.message);
  final String id;
  final String message;
}

class _Completed extends TransfersEvent {
  const _Completed(this.id, {this.remoteName, this.savedLocation});
  final String id;
  final String? remoteName;
  final String? savedLocation;
}

class _Failed extends TransfersEvent {
  const _Failed(this.id, this.failure);
  final String id;
  final Failure failure;
}
