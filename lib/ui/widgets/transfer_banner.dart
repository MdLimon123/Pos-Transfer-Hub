import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/auth_cubit.dart';
import '../../features/transfers/bloc/transfers_bloc.dart';
import '../../features/transfers/models/transfer_task.dart';
import '../tab_cubit.dart';
import '../theme.dart';

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

    final title = '${items.length} transfer${items.length == 1 ? '' : 's'} in progress';
    final subtitle = [
      if (running > 0) '$running active',
      if (waiting > 0) 'waiting for network',
      if (paused > 0) '$paused paused',
    ].join(' · ');

    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 84,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.brandDark, AppTheme.seed],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              navigatorKey.currentState?.popUntil((r) => r.isFirst);
              context.read<TabCubit>().select(TabCubit.transfers);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 3.2,
                          value: progress,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                        if (progress != null)
                          Text('${(progress * 100).floor()}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5)),
                        if (subtitle.isNotEmpty)
                          Text(subtitle,
                              style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
