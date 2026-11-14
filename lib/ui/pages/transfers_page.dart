import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/transfers/bloc/transfers_bloc.dart';
import '../widgets/transfer_tile.dart';

/// Global dashboard: every upload and download, newest first.
class TransfersPage extends StatelessWidget {
  const TransfersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransfersBloc>().state;
    final tasks = state.tasks;

    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_vert, size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              const Text('No transfers yet.\nUploads and downloads will appear here.',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final activeCount = state.unfinished.length;
    final hasFinished = tasks.any((t) => t.isFinished);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  activeCount > 0 ? '$activeCount in progress' : 'All caught up',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (hasFinished)
                TextButton(
                  onPressed: () => context.read<TransfersBloc>().add(const FinishedTransfersCleared()),
                  child: const Text('Clear finished'),
                ),
            ],
          ),
        ),
        for (final t in tasks) TransferTile(key: ValueKey(t.id), task: t),
      ],
    );
  }
}
