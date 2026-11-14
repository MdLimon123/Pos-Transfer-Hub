import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/format.dart';
import '../../features/transfers/bloc/transfers_bloc.dart';
import '../../features/transfers/models/transfer_task.dart';
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
    if (_picking) return;
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
    final muted = scheme.onSurfaceVariant;
    final uploads = context
        .watch<TransfersBloc>()
        .state
        .tasks
        .where((t) => t.type == TransferType.upload)
        .toList();
    final recent = uploads.where((t) => t.status == TransferStatus.completed).take(4).toList();
    final current = uploads.where((t) => t.status != TransferStatus.completed).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 170),
      children: [
        // Drop zone (the whole area is tappable)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: DashedBorder(
            color: scheme.primary.withValues(alpha: 0.5),
            radius: 26,
            child: Material(
              color: scheme.primaryContainer.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(26),
              child: InkWell(
                borderRadius: BorderRadius.circular(26),
                onTap: _pick,
                child: SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.18),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(Icons.cloud_upload_outlined, size: 38, color: scheme.primary),
                      ),
                      const SizedBox(height: 20),
                      Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17),
                          children: [
                            TextSpan(
                              text: 'Click to upload',
                              style: TextStyle(
                                  color: scheme.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: scheme.primary),
                            ),
                            const TextSpan(text: ' a file'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Images, videos, CSV and more',
                          style: TextStyle(fontSize: 13.5, color: muted)),
                      const SizedBox(height: 2),
                      Text('Keeps uploading in the background',
                          style: TextStyle(fontSize: 12.5, color: muted.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          child: Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('or', style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
            ),
            const Expanded(child: Divider()),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _picking ? null : _pick,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
              icon: _picking
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.folder_open_rounded),
              label: Text(_picking ? 'Opening…' : 'Choose File'),
            ),
          ),
        ),
        if (current.isNotEmpty) ...[
          SectionHeader('In progress',
              trailing: StatusPill(label: '${current.length}', color: scheme.primary)),
          for (final t in current) TransferTile(key: ValueKey(t.id), task: t),
        ],
        if (recent.isNotEmpty) ...[
          const SectionHeader('Recent uploaded'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [for (final t in recent) _RecentCard(task: t)],
            ),
          ),
        ],
        if (uploads.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 28, color: scheme.outline),
                const SizedBox(height: 8),
                Text('No uploads yet', style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Your uploads will show up here.',
                    style: TextStyle(fontSize: 13, color: scheme.outline)),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.task});
  final TransferTask task;

  @override
  Widget build(BuildContext context) {
    final kind = fileKindOf(task.name);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kind.color.withValues(alpha: dark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: kind.color, shape: BoxShape.circle),
                child: Icon(kind.icon, size: 21, color: Colors.white),
              ),
              const Spacer(),
              Icon(Icons.check_circle_rounded, size: 20, color: kind.color),
            ],
          ),
          const Spacer(),
          Text(task.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 14.5)),
          const SizedBox(height: 2),
          Text(formatBytes(task.totalBytes),
              style: TextStyle(
                  fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
