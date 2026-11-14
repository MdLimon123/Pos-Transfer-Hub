import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/auth_cubit.dart';
import '../../features/transfers/bloc/transfers_bloc.dart';
import '../../features/transfers/models/transfer_task.dart';
import '../tab_cubit.dart';

/// Floating strip shown above every screen while something is transferring.
/// Tapping it jumps to the Transfers dashboard.
class TransferBanner extends StatelessWidget {
  const TransferBanner({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    final signedIn =
        context.select((AuthCubit c) => c.state.status == AuthStatus.authenticated);
    final onTransfersTab = context.select((TabCubit c) => c.state == TabCubit.transfers);
    final state = context.watch<TransfersBloc>().state;
    final items = state.unfinished.toList();

    if (!signedIn || onTransfersTab || items.isEmpty) return const SizedBox.shrink();

    final running = items.where((t) => t.status == TransferStatus.running).length;
    final paused = items.where((t) => t.status == TransferStatus.paused).length;
    final waiting = items.where((t) => t.status == TransferStatus.waitingNetwork).length;
    final progress = state.overallProgress;
    final scheme = Theme.of(context).colorScheme;

    final label = StringBuffer('${items.length} transfer${items.length == 1 ? '' : 's'}');
    if (running > 0) label.write(' • $running active');
    if (waiting > 0) label.write(' • waiting for network');
    if (paused > 0) label.write(' • $paused paused');

    return Positioned(
      left: 12,
      right: 12,
      bottom: MediaQuery.of(context).padding.bottom + 88,
      child: Material(
        color: scheme.inverseSurface,
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            navigatorKey.currentState?.popUntil((r) => r.isFirst);
            context.read<TabCubit>().select(TabCubit.transfers);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        value: running > 0 ? null : 0,
                        color: scheme.onInverseSurface,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label.toString(),
                          style: TextStyle(
                              color: scheme.onInverseSurface, fontWeight: FontWeight.w600)),
                    ),
                    if (progress != null)
                      Text('${(progress * 100).floor()}%',
                          style: TextStyle(
                              color: scheme.onInverseSurface, fontWeight: FontWeight.w700)),
                    Icon(Icons.chevron_right, color: scheme.onInverseSurface),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    color: scheme.inversePrimary,
                    backgroundColor: scheme.onInverseSurface.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
