import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/format.dart';
import '../../features/transfers/bloc/transfers_bloc.dart';
import '../../features/transfers/models/transfer_task.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/transfer_tile.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  bool _picking = false;

  Future<void> _pick() async {
    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<TransfersBloc>();
    setState(() => _picking = true);
    try {
      final picked = await FilePicker.pickFile();
      if (picked == null) return;

      final path = picked.path;
      final size = await picked.length() ?? (path != null ? await File(path).length() : 0);
      if (path == null || !await File(path).exists()) {
        messenger.showSnackBar(const SnackBar(
            content: Text('That file cannot be read. Choose one stored on this device.')));
        return;
      }
      if (size == 0) {
        messenger.showSnackBar(const SnackBar(content: Text('The selected file is empty.')));
        return;
      }
      bloc.add(UploadRequested(path: path, name: picked.name, size: size));
      messenger.showSnackBar(SnackBar(
          content: Text('Uploading ${picked.name} (${formatBytes(size)}). '
              'You can leave this screen – it keeps running.')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not open the file picker. Please try again.')));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uploads = context
        .watch<TransfersBloc>()
        .state
        .tasks
        .where((t) => t.type == TransferType.upload)
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 170),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DashedBorder(
            color: scheme.primary.withValues(alpha: 0.45),
            radius: AppTheme.radius + 6,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radius + 6),
                color: scheme.primaryContainer.withValues(alpha: 0.28),
              ),
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppTheme.seed, AppTheme.brandLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.cloud_upload_rounded, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  Text('Upload a file', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Pick a large image, video or CSV. Uploads keep running in the '
                    'background even if you switch screens or minimise the app.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _TypeChip(Icons.image_rounded, 'Images', Color(0xFF7C5CFF)),
                      _TypeChip(Icons.movie_rounded, 'Videos', Color(0xFFE5484D)),
                      _TypeChip(Icons.table_chart_rounded, 'CSV', Color(0xFF2E9E6B)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _picking ? null : _pick,
                      icon: _picking
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add_rounded),
                      label: Text(_picking ? 'Opening…' : 'Choose file'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (uploads.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 36, 32, 0),
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 30, color: scheme.outline),
                const SizedBox(height: 8),
                Text('No uploads yet',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text('Your uploads will show up here.',
                    style: TextStyle(fontSize: 13, color: scheme.outline)),
              ],
            ),
          )
        else ...[
          SectionHeader('Recent uploads',
              trailing: StatusPill(label: '${uploads.length}', color: scheme.primary)),
          for (final t in uploads) TransferTile(key: ValueKey(t.id), task: t),
        ],
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      );
}
