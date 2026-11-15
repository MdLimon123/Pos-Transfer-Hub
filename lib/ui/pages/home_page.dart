import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/files/files_cubit.dart';
import '../../features/transfers/bloc/transfers_bloc.dart';
import '../../features/transfers/models/transfer_task.dart';
import '../tab_cubit.dart';
import 'files_page.dart';
import 'profile_page.dart';
import 'transfers_page.dart';
import 'upload_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    context.read<FilesCubit>().load();
  }

  static const _titles = ['Upload', 'Files', 'Transfers', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<TabCubit>().state;
    final activeCount =
        context.select((TransfersBloc b) => b.state.unfinished.length);

    return MultiBlocListener(
      listeners: [
      
        BlocListener<TransfersBloc, TransfersState>(
          listenWhen: (a, b) => _completedUploads(b) > _completedUploads(a),
          listener: (context, _) => context.read<FilesCubit>().load(),
        ),
       
        BlocListener<TransfersBloc, TransfersState>(
          listenWhen: (a, b) => b.tasks.any((t) =>
              t.status == TransferStatus.failed && a.byId(t.id)?.status != TransferStatus.failed),
          listener: (context, state) {
            final failed = state.tasks.firstWhere((t) => t.status == TransferStatus.failed);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text('${failed.name}: ${failed.message ?? 'transfer failed'}'),
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () => context.read<TransfersBloc>().add(TransferRetried(failed.id)),
                ),
              ));
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[tab]),
          actions: [
            if (tab != TabCubit.transfers)
              IconButton(
                tooltip: 'Transfers',
                onPressed: () => context.read<TabCubit>().select(TabCubit.transfers),
                icon: Badge(
                  isLabelVisible: activeCount > 0,
                  label: Text('$activeCount'),
                  child: const Icon(Icons.swap_vert_rounded),
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: IndexedStack(
          index: tab,
          children: const [UploadPage(), FilesPage(), TransfersPage(), ProfilePage()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: context.read<TabCubit>().select,
          destinations: [
            const NavigationDestination(icon: Icon(Icons.cloud_upload_outlined), selectedIcon: Icon(Icons.cloud_upload_rounded), label: 'Upload'),
            const NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder_rounded), label: 'Files'),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: activeCount > 0,
                label: Text('$activeCount'),
                child: const Icon(Icons.swap_vert_rounded),
              ),
              label: 'Transfers',
            ),
            const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile'),
          ],
        ),
      ),
    );
  }

  int _completedUploads(TransfersState s) => s.tasks
      .where((t) => t.isUpload && t.status == TransferStatus.completed)
      .length;
}
