import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/format.dart';
import '../../core/storage_bridge.dart';
import '../../features/transfers/bloc/transfers_bloc.dart';
import '../../features/transfers/models/transfer_task.dart';

String statusLabel(TransferTask t) => switch (t.status) {
      TransferStatus.queued => 'Queued',
      TransferStatus.running => t.isUpload ? 'Uploading' : 'Downloading',
      TransferStatus.paused => 'Paused',
      TransferStatus.waitingNetwork => 'Waiting for network',
      TransferStatus.completed => 'Completed',
      TransferStatus.failed => 'Failed',
      TransferStatus.canceled => 'Canceled',
    };

Color statusColor(BuildContext context, TransferTask t) {
  final scheme = Theme.of(context).colorScheme;
  return switch (t.status) {
    TransferStatus.completed => Colors.green.shade700,
    TransferStatus.failed => scheme.error,
    TransferStatus.paused || TransferStatus.waitingNetwork => Colors.orange.shade800,
    TransferStatus.canceled => scheme.outline,
    _ => scheme.primary,
  };
}

/// Progress bar + percentage + byte counts for one transfer.
class TransferProgress extends StatelessWidget {
  const TransferProgress({super.key, required this.task});
  final TransferTask task;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(context, task);
    final bytes = task.totalBytes > 0
        ? '${formatBytes(task.transferredBytes)} / ${formatBytes(task.totalBytes)}'
        : formatBytes(task.transferredBytes);
    final indeterminate = task.status == TransferStatus.running && task.progress == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: indeterminate ? null : (task.progress ?? 0),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('${task.percent}%',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(bytes,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ],
    );
  }
}

/// One row of the transfer list with the actions that make sense for its state.
class TransferTile extends StatelessWidget {
  const TransferTile({super.key, required this.task});
  final TransferTask task;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TransfersBloc>();
    final color = statusColor(context, task);
    final showBar = !task.isFinished || task.status == TransferStatus.completed;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(task.isUpload ? Icons.upload_file : Icons.download_for_offline,
                    color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        '${task.isUpload ? 'Upload' : 'Download'} • ${statusLabel(task)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: color, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                ..._actions(context, bloc),
              ],
            ),
            if (showBar)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: TransferProgress(task: task),
              ),
            if (task.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task.status == TransferStatus.failed)
                      Padding(
                        padding: const EdgeInsets.only(right: 6, top: 1),
                        child: Icon(Icons.error_outline,
                            size: 16, color: Theme.of(context).colorScheme.error),
                      ),
                    Expanded(
                      child: Text(
                        task.message!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: task.status == TransferStatus.failed
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, TransfersBloc bloc) {
    Widget btn(IconData icon, String tip, VoidCallback onTap) =>
        IconButton(icon: Icon(icon), tooltip: tip, onPressed: onTap, visualDensity: VisualDensity.compact);

    switch (task.status) {
      case TransferStatus.queued:
      case TransferStatus.running:
        return [
          btn(Icons.pause_circle_outline, 'Pause', () => bloc.add(TransferPaused(task.id))),
          btn(Icons.close, 'Cancel', () => bloc.add(TransferCanceled(task.id))),
        ];
      case TransferStatus.waitingNetwork:
        return [
          btn(Icons.pause_circle_outline, 'Pause', () => bloc.add(TransferPaused(task.id))),
          btn(Icons.close, 'Cancel', () => bloc.add(TransferCanceled(task.id))),
        ];
      case TransferStatus.paused:
        return [
          btn(Icons.play_circle_outline, 'Resume', () => bloc.add(TransferResumed(task.id))),
          btn(Icons.close, 'Cancel', () => bloc.add(TransferCanceled(task.id))),
        ];
      case TransferStatus.failed:
        return [
          btn(Icons.refresh, 'Retry', () => bloc.add(TransferRetried(task.id))),
          btn(Icons.delete_outline, 'Remove', () => bloc.add(TransferRemoved(task.id))),
        ];
      case TransferStatus.completed:
        return [
          if (!task.isUpload && task.savedLocation != null)
            btn(Icons.open_in_new, 'Open', () => _open(context)),
          btn(Icons.delete_outline, 'Remove from list', () => bloc.add(TransferRemoved(task.id))),
        ];
      case TransferStatus.canceled:
        return [
          btn(Icons.delete_outline, 'Remove', () => bloc.add(TransferRemoved(task.id))),
        ];
    }
  }

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<StorageBridge>().open(task.savedLocation!, task.name);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
          content: Text('No app found to open this file. It is saved in Downloads/TransferHub.')));
    }
  }
}
