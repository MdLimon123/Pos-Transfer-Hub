import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/format.dart';
import '../../features/auth/auth_cubit.dart';
import '../../features/files/files_cubit.dart';
import '../../features/transfers/bloc/transfers_bloc.dart';
import '../../features/transfers/models/transfer_task.dart';
import '../theme.dart';


class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = context.read<AuthCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.logout_rounded, size: 30, color: Theme.of(ctx).colorScheme.error),
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to upload or download files.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = context.select((AuthCubit c) => c.state.user) ?? 'User';
    final tasks = context.select((TransfersBloc b) => b.state.tasks);
    final files = context.select((FilesCubit c) => c.state.files);

    final uploaded =
        tasks.where((t) => t.isUpload && t.status == TransferStatus.completed).length;
    final downloaded =
        tasks.where((t) => !t.isUpload && t.status == TransferStatus.completed).length;
    final stored = files.fold<int>(0, (a, f) => a + f.size);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius + 10),
            gradient: const LinearGradient(
              colors: [AppTheme.brandDark, AppTheme.seed, AppTheme.brandLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentGold, width: 2.5),
                ),
                child: Text(user.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 14),
              Text(user,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
              const SizedBox(height: 4),
              const Text('Signed in',
                  style: TextStyle(color: Colors.white70, fontSize: 13.5)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _Stat(Icons.north_east_rounded, '$uploaded', 'Uploaded')),
            const SizedBox(width: 10),
            Expanded(child: _Stat(Icons.south_west_rounded, '$downloaded', 'Downloaded')),
            const SizedBox(width: 10),
            Expanded(child: _Stat(Icons.cloud_done_outlined, formatBytes(stored), 'On server')),
          ],
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: () => _confirmLogout(context),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            foregroundColor: scheme.error,
            side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.value, this.label);
  final IconData icon;
  final String value, label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppTheme.accentGold),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
