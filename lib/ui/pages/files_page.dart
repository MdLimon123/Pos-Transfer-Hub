import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/storage_bridge.dart';
import '../../features/files/files_cubit.dart';
import '../../features/transfers/bloc/transfers_bloc.dart';
import '../../features/transfers/models/remote_file.dart';
import '../../features/transfers/models/transfer_task.dart';
import '../widgets/transfer_tile.dart';

/// Files stored on the server, each with a download button and live progress.
class FilesPage extends StatelessWidget {
  const FilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final files = context.watch<FilesCubit>().state;
    final transfers = context.watch<TransfersBloc>().state;

    Widget body;
    if (files.files.isEmpty && files.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (files.files.isEmpty && files.error != null) {
      body = _Message(
        icon: Icons.cloud_off,
        text: files.error!,
        action: FilledButton(
            onPressed: () => context.read<FilesCubit>().load(), child: const Text('Try again')),
      );
    } else if (files.files.isEmpty) {
      body = const _Message(
          icon: Icons.folder_open, text: 'No files on the server yet.\nUpload one first.');
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.only(bottom: 160),
        itemCount: files.files.length + (files.error != null ? 1 : 0),
        itemBuilder: (context, i) {
          if (files.error != null && i == 0) {
            return MaterialBanner(
              content: Text(files.error!),
              actions: [
                TextButton(
                    onPressed: () => context.read<FilesCubit>().load(),
                    child: const Text('Retry'))
              ],
            );
          }
          final file = files.files[i - (files.error != null ? 1 : 0)];
          return _FileCard(file: file, task: transfers.downloadOf(file.name));
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<FilesCubit>().load(),
      child: body is ListView
          ? body
          : LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(height: c.maxHeight, child: body),
              ),
            ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.file, required this.task});
  final RemoteFile file;
  final TransferTask? task;

  @override
  Widget build(BuildContext context) {
    // Show the live tile while a download of this file is in flight / paused / failed.
    final t = task;
    if (t != null && t.status != TransferStatus.completed && t.status != TransferStatus.canceled) {
      return TransferTile(key: ValueKey(t.id), task: t);
    }

    final done = t?.status == TransferStatus.completed;
    final date = file.uploadedAt != null ? DateFormat.yMMMd().add_jm().format(file.uploadedAt!) : '';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(_iconFor(file.type), size: 32),
        title: Text(file.originalName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([formatBytes(file.size), if (date.isNotEmpty) date].join(' • ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (done && t!.savedLocation != null)
              IconButton(
                tooltip: 'Open downloaded copy',
                icon: const Icon(Icons.open_in_new),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await context.read<StorageBridge>().open(t.savedLocation!, t.name);
                  if (!ok) {
                    messenger.showSnackBar(
                        const SnackBar(content: Text('No app found to open this file.')));
                  }
                },
              ),
            IconButton(
              tooltip: done ? 'Download again' : 'Download',
              icon: Icon(done ? Icons.download_done : Icons.download),
              onPressed: () => context.read<TransfersBloc>().add(DownloadRequested(
                    remoteName: file.name,
                    displayName: file.originalName,
                    url: file.url,
                    size: file.size,
                  )),
            ),
            PopupMenuButton<String>(
              onSelected: (_) => _confirmDelete(context),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete from server')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<FilesCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('"${file.originalName}" will be removed from the server.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final error = await cubit.delete(file);
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'File deleted.')));
  }

  IconData _iconFor(String? mime) {
    if (mime == null) return Icons.insert_drive_file_outlined;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.startsWith('video/')) return Icons.movie_outlined;
    if (mime.contains('csv') || mime.contains('sheet')) return Icons.table_chart_outlined;
    return Icons.insert_drive_file_outlined;
  }
}
