import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/format.dart';
import '../../features/transfers/bloc/transfers_bloc.dart';
import '../../features/transfers/models/transfer_task.dart';
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
    final uploads = context
        .watch<TransfersBloc>()
        .state
        .tasks
        .where((t) => t.type == TransferType.upload)
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 160),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      size: 56, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 8),
                  Text('Upload a file', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Pick a large image, video or CSV. Uploads continue in the background, '
                    'even if you switch screens or minimise the app.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _picking ? null : _pick,
                    icon: _picking
                        ? const SizedBox(
                            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.attach_file),
                    label: Text(_picking ? 'Opening…' : 'Choose file'),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (uploads.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text('No uploads yet.',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Uploads', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final t in uploads) TransferTile(key: ValueKey(t.id), task: t),
        ],
      ],
    );
  }
}
