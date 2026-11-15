import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/storage_bridge.dart';
import '../../features/files/files_cubit.dart';
import '../../features/transfers/bloc/transfers_bloc.dart';
import '../../features/transfers/models/remote_file.dart';
import '../../features/transfers/models/transfer_task.dart';
import '../widgets/common.dart';
import '../widgets/transfer_tile.dart';


class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final files = context.watch<FilesCubit>().state;
    final transfers = context.watch<TransfersBloc>().state;

    Widget body;
    if (files.files.isEmpty && files.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (files.files.isEmpty && files.error != null) {
      body = EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn\'t load files',
        message: files.error!,
        action: FilledButton.icon(
          onPressed: () => context.read<FilesCubit>().load(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      );
    } else if (files.files.isEmpty) {
      body = const EmptyState(
        icon: Icons.folder_open_rounded,
        title: 'No files yet',
        message: 'Files you upload will appear here, ready to download.',
      );
    } else {
      final q = _query.trim().toLowerCase();
      final shown = q.isEmpty
          ? files.files
          : files.files.where((f) => f.originalName.toLowerCase().contains(q)).toList();
      final total = files.files.fold<int>(0, (a, f) => a + f.size);
      final scheme = Theme.of(context).colorScheme;
      body = ListView(
        padding: const EdgeInsets.only(bottom: 170),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search files',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => setState(() => _query = ''),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Text(
              '${shown.length} file${shown.length == 1 ? '' : 's'} · ${formatBytes(total)} total',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
            ),
          ),
          if (files.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Card(
                child: ListTile(
                  leading: Icon(Icons.error_outline_rounded, color: scheme.error),
                  title: Text(files.error!, style: const TextStyle(fontSize: 13.5)),
                  trailing: TextButton(
                      onPressed: () => context.read<FilesCubit>().load(),
                      child: const Text('Retry')),
                ),
              ),
            ),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matches',
                message: 'Try a different file name.',
              ),
            )
          else
            for (final file in shown)
              _FileCard(
                  key: ValueKey(file.name),
                  file: file,
                  task: transfers.downloadOf(file.name)),
        ],
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

class _FileCard extends StatelessWidget {
  const _FileCard({super.key, required this.file, required this.task});
  final RemoteFile file;
  final TransferTask? task;

  @override
  Widget build(BuildContext context) {
  
    final t = task;
    if (t != null && t.status != TransferStatus.completed && t.status != TransferStatus.canceled) {
      return TransferTile(key: ValueKey(t.id), task: t);
    }

    final scheme = Theme.of(context).colorScheme;
    final done = t?.status == TransferStatus.completed;
    final date = file.uploadedAt != null ? DateFormat.yMMMd().add_jm().format(file.uploadedAt!) : '';
    final kind = fileKindOf(file.originalName, file.type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          child: Row(
            children: [
              FileTypeTile(kind: kind, size: 48, circle: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(file.originalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      [formatBytes(file.size), if (date.isNotEmpty) date].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                    if (done) ...[
                      const SizedBox(height: 6),
                      const StatusPill(
                          label: 'Downloaded',
                          color: Color(0xFF2E9E6B),
                          icon: Icons.check_circle_rounded),
                    ],
                  ],
                ),
              ),
              if (done && t!.savedLocation != null)
                IconButton(
                  tooltip: 'Open downloaded copy',
                  icon: const Icon(Icons.open_in_new_rounded, size: 21),
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await context.read<StorageBridge>().open(t.savedLocation!, t.name);
                    if (!ok) {
                      messenger.showSnackBar(
                          const SnackBar(content: Text('No app found to open this file.')));
                    }
                  },
                ),
              IconButton.filledTonal(
                tooltip: done ? 'Download again' : 'Download',
                icon: Icon(done ? Icons.refresh_rounded : Icons.download_rounded, size: 21),
                onPressed: () => context.read<TransfersBloc>().add(DownloadRequested(
                      remoteName: file.name,
                      displayName: file.originalName,
                      url: file.url,
                      size: file.size,
                    )),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 21),
                onSelected: (_) => _confirmDelete(context),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 20, color: scheme.error),
                      const SizedBox(width: 10),
                      Text('Delete from server', style: TextStyle(color: scheme.error)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
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
        icon: Icon(Icons.delete_outline_rounded,
            size: 32, color: Theme.of(ctx).colorScheme.error),
        title: const Text('Delete file?'),
        content: Text('"${file.originalName}" will be permanently removed from the server.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await cubit.delete(file);
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'File deleted.')));
  }
}
