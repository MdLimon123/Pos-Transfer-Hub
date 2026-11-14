import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/format.dart';
import '../../core/storage_bridge.dart';
import '../../features/transfers/bloc/transfers_bloc.dart';
import '../../features/transfers/models/transfer_task.dart';
import 'common.dart';

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
    TransferStatus.completed => const Color(0xFF2E9E6B),
    TransferStatus.failed => scheme.error,
    TransferStatus.paused || TransferStatus.waitingNetwork => const Color(0xFFD98A00),
    TransferStatus.canceled => scheme.outline,
    _ => scheme.primary,
  };
}

IconData statusIcon(TransferTask t) => switch (t.status) {
      TransferStatus.queued => Icons.schedule_rounded,
      TransferStatus.running => t.isUpload ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
      TransferStatus.paused => Icons.pause_rounded,
      TransferStatus.waitingNetwork => Icons.wifi_off_rounded,
      TransferStatus.completed => Icons.check_rounded,
      TransferStatus.failed => Icons.error_outline_rounded,
      TransferStatus.canceled => Icons.close_rounded,
    };

/// Progress bar + percentage + byte counts for one transfer.
class TransferProgress extends StatelessWidget {
  const TransferProgress({super.key, required this.task});
  final TransferTask task;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(context, task);
    final bytes = task.totalBytes > 0
        ? '${formatBytes(task.transferredBytes)} of ${formatBytes(task.totalBytes)}'
        : formatBytes(task.transferredBytes);
    final indeterminate = task.status == TransferStatus.running && task.progress == null;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: indeterminate ? null : (task.progress ?? 0),
            minHeight: 7,
            color: color,
            backgroundColor: color.withValues(alpha: 0.14),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Text('${task.percent}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(bytes,
                  style: TextStyle(fontSize: 12, color: muted),
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
    final scheme = Theme.of(context).colorScheme;
    final showBar = !task.isFinished || task.status == TransferStatus.completed;
    final failed = task.status == TransferStatus.failed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FileTypeTile(kind: fileKindOf(task.name)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontSize: 15)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(task.isUpload ? Icons.north_east_rounded : Icons.south_west_rounded,
                                size: 13, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Text(task.isUpload ? 'Upload' : 'Download',
                                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: StatusPill(
                                  label: statusLabel(task),
                                  color: color,
                                  icon: statusIcon(task)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ..._actions(context, bloc),
                ],
              ),
              if (showBar)
                Padding(
                  padding: const EdgeInsets.only(top: 12, right: 6),
                  child: TransferProgress(task: task),
                ),
              if (task.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10, right: 6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: (failed ? scheme.error : scheme.outline).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      task.message!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: failed ? scheme.error : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, TransfersBloc bloc) {
    Widget btn(IconData icon, String tip, VoidCallback onTap, {Color? color}) => IconButton(
          icon: Icon(icon, size: 22),
          tooltip: tip,
          color: color,
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
        );
    final pause = btn(Icons.pause_circle_outline_rounded, 'Pause', () => bloc.add(TransferPaused(task.id)));
    final cancel = btn(Icons.close_rounded, 'Cancel', () => bloc.add(TransferCanceled(task.id)));

    switch (task.status) {
      case TransferStatus.queued:
      case TransferStatus.running:
      case TransferStatus.waitingNetwork:
        return [pause, cancel];
      case TransferStatus.paused:
        return [
          btn(Icons.play_circle_fill_rounded, 'Resume', () => bloc.add(TransferResumed(task.id)),
              color: Theme.of(context).colorScheme.primary),
          cancel,
        ];
      case TransferStatus.failed:
        return [
          btn(Icons.refresh_rounded, 'Retry', () => bloc.add(TransferRetried(task.id)),
              color: Theme.of(context).colorScheme.primary),
          btn(Icons.delete_outline_rounded, 'Remove', () => bloc.add(TransferRemoved(task.id))),
        ];
      case TransferStatus.completed:
        return [
          if (!task.isUpload && task.savedLocation != null)
            btn(Icons.open_in_new_rounded, 'Open', () => _open(context)),
          btn(Icons.delete_outline_rounded, 'Remove from list', () => bloc.add(TransferRemoved(task.id))),
        ];
      case TransferStatus.canceled:
        return [btn(Icons.delete_outline_rounded, 'Remove', () => bloc.add(TransferRemoved(task.id)))];
    }
  }

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<StorageBridge>().open(task.savedLocation!, task.name);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
          content: Text('No app found to open this file. It is saved in the TransferHub folder.')));
    }
  }
}
