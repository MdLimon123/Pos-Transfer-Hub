import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/transfers/bloc/transfers_bloc.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/transfer_tile.dart';

enum _Filter { all, active, done }

/// Global dashboard: every upload and download, newest first.
class TransfersPage extends StatefulWidget {
  const TransfersPage({super.key});

  @override
  State<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends State<TransfersPage> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransfersBloc>().state;
    final tasks = state.tasks;

    if (tasks.isEmpty) {
      return const EmptyState(
        icon: Icons.swap_vert_rounded,
        title: 'No transfers yet',
        message: 'Uploads and downloads will appear here with live progress.',
      );
    }

    final unfinished = state.unfinished.toList();
    final activeCount = unfinished.length;
    final hasFinished = tasks.any((t) => t.isFinished);
    final uploads = unfinished.where((t) => t.isUpload).length;
    final downloads = activeCount - uploads;
    final progress = state.overallProgress;

    final visible = tasks.where((t) => switch (_filter) {
          _Filter.all => true,
          _Filter.active => !t.isFinished,
          _Filter.done => t.isFinished,
        }).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _SummaryCard(
            active: activeCount,
            uploads: uploads,
            downloads: downloads,
            progress: progress,
            total: tasks.length,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<_Filter>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  segments: const [
                    ButtonSegment(value: _Filter.all, label: Text('All')),
                    ButtonSegment(value: _Filter.active, label: Text('Active')),
                    ButtonSegment(value: _Filter.done, label: Text('Finished')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
              ),
              if (hasFinished) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Clear finished',
                  onPressed: () =>
                      context.read<TransfersBloc>().add(const FinishedTransfersCleared()),
                  icon: const Icon(Icons.cleaning_services_outlined, size: 21),
                ),
              ],
            ],
          ),
        ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              _filter == _Filter.active ? 'Nothing in progress' : 'Nothing finished yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          )
        else
          for (final t in visible) TransferTile(key: ValueKey(t.id), task: t),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.active,
    required this.uploads,
    required this.downloads,
    required this.progress,
    required this.total,
  });
  final int active, uploads, downloads, total;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final idle = active == 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius + 6),
        gradient: const LinearGradient(
          colors: [AppTheme.brandDark, AppTheme.seed, AppTheme.brandLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.seed.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(idle ? 'All caught up' : '$active in progress',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4)),
                    const SizedBox(height: 4),
                    Text(
                      idle
                          ? '$total transfer${total == 1 ? '' : 's'} in history'
                          : '$uploads uploading · $downloads downloading',
                      style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accentGold, width: 2)),
                child: Icon(idle ? Icons.check_rounded : Icons.sync_rounded,
                    color: Colors.white, size: 26),
              ),
            ],
          ),
          if (!idle) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(height: 6),
            Text(progress != null ? '${(progress! * 100).floor()}% overall' : 'Starting…',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
