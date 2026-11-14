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
      TransferStatus.completed => t.isUpload ? 'Uploaded' : 'Downloaded',
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

/// Compact "pill" row: type icon, name + percent, status line, slim progress
/// bar, and round action buttons on the right.
class TransferTile extends StatelessWidget {
  const TransferTile({super.key, required this.task});
  final TransferTask task;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TransfersBloc>();
    final scheme = Theme.of(context).colorScheme;
    final color = statusColor(context, task);
    final muted = scheme.onSurfaceVariant;

    final failed = task.status == TransferStatus.failed;
    final completed = task.status == TransferStatus.completed;
    final showBar = !task.isFinished;
    final bytes = task.totalBytes > 0
        ? '${formatBytes(task.transferredBytes)} of ${formatBytes(task.totalBytes)}'
        : formatBytes(task.transferredBytes);

    final String sub;
    if (failed) {
      sub = task.message ?? 'Failed';
    } else if (completed) {
      sub = '${statusLabel(task)} · ${formatBytes(task.totalBytes)}';
    } else if (task.status == TransferStatus.canceled) {
      sub = 'Canceled';
    } else {
      sub = '${statusLabel(task)} · ${task.message ?? bytes}';
    }
    final subColor = (failed || task.status == TransferStatus.paused ||
            task.status == TransferStatus.waitingNetwork)
        ? color
        : muted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: failed ? scheme.error.withValues(alpha: 0.35) : scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              FileTypeTile(kind: fileKindOf(task.name), size: 48, circle: true),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                  child: Icon(_badgeIcon(), size: 11, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(task.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontSize: 15)),
                    ),
                    if (showBar) ...[
                      const SizedBox(width: 8),
                      Text('${task.percent}%',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800, color: color)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: subColor)),
                if (showBar) ...[
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: task.status == TransferStatus.running && task.progress == null
                          ? null
                          : (task.progress ?? 0),
                      minHeight: 6,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.14),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          ..._actions(context, bloc),
        ],
      ),
    );
  }

  IconData _badgeIcon() => switch (task.status) {
        TransferStatus.queued => Icons.schedule_rounded,
        TransferStatus.running =>
          task.isUpload ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        TransferStatus.paused => Icons.pause_rounded,
        TransferStatus.waitingNetwork => Icons.wifi_off_rounded,
        TransferStatus.completed => Icons.check_rounded,
        TransferStatus.failed => Icons.priority_high_rounded,
        TransferStatus.canceled => Icons.close_rounded,
      };

  List<Widget> _actions(BuildContext context, TransfersBloc bloc) {
    final scheme = Theme.of(context).colorScheme;
    Widget btn(IconData icon, String tip, VoidCallback onTap, {bool primary = false}) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: IconButton(
            tooltip: tip,
            onPressed: onTap,
            iconSize: 19,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            style: IconButton.styleFrom(
              backgroundColor:
                  primary ? scheme.primary : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
              foregroundColor: primary ? scheme.onPrimary : scheme.onSurface,
            ),
            icon: Icon(icon),
          ),
        );
    final pause = btn(Icons.pause_rounded, 'Pause', () => bloc.add(TransferPaused(task.id)));
    final cancel = btn(Icons.close_rounded, 'Cancel', () => bloc.add(TransferCanceled(task.id)));
    final remove = btn(Icons.delete_outline_rounded, 'Remove', () => bloc.add(TransferRemoved(task.id)));

    switch (task.status) {
      case TransferStatus.queued:
      case TransferStatus.running:
      case TransferStatus.waitingNetwork:
        return [pause, cancel];
      case TransferStatus.paused:
        return [
          btn(Icons.play_arrow_rounded, 'Resume', () => bloc.add(TransferResumed(task.id)),
              primary: true),
          cancel,
        ];
      case TransferStatus.failed:
        return [
          btn(Icons.refresh_rounded, 'Retry', () => bloc.add(TransferRetried(task.id)),
              primary: true),
          remove,
        ];
      case TransferStatus.completed:
        return [
          if (!task.isUpload && task.savedLocation != null)
            btn(Icons.open_in_new_rounded, 'Open', () => _open(context)),
          remove,
        ];
      case TransferStatus.canceled:
        return [remove];
    }
  }

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<StorageBridge>().open(task.savedLocation!, task.name);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
          content: Text('No app found to open this file. It is saved in the Transfer Hub folder.')));
    }
  }
}
