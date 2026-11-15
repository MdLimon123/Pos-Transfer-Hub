import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/foreground_service.dart';
import 'core/notification_service.dart';
import 'core/storage_bridge.dart';
import 'features/auth/auth_cubit.dart';
import 'features/auth/auth_repository.dart';
import 'features/files/files_cubit.dart';
import 'features/files/files_repository.dart';
import 'features/transfers/bloc/transfers_bloc.dart';
import 'features/transfers/data/transfer_service.dart';
import 'features/transfers/data/transfer_store.dart';
import 'ui/tab_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  final notifications = NotificationService();
  await notifications.init();

  final authRepo = AuthRepository();
  final dio = createApiClient(authRepo);
  final storage = StorageBridge();

  final authCubit = AuthCubit(authRepo)..restore();
  final transfers = TransfersBloc(
    service: TransferService(dio),
    store: TransferStore(),
    notifications: notifications,
    foreground: ForegroundTransferService(notifications),
    storage: storage,
  )..add(const TransfersStarted());

 
  final connectivity = Connectivity();
  unawaited(connectivity.checkConnectivity().then(
      (r) => transfers.add(ConnectivityChanged(online: !r.contains(ConnectivityResult.none)))));
  connectivity.onConnectivityChanged.listen(
      (r) => transfers.add(ConnectivityChanged(online: !r.contains(ConnectivityResult.none))));

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: storage),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: authCubit),
          BlocProvider.value(value: transfers),
          BlocProvider(create: (_) => FilesCubit(FilesRepository(dio))),
          BlocProvider(
              create: (_) => TabCubit(initial: TabCubit.fromPayload(notifications.launchPayload))),
        ],
        child: TransferHubApp(notifications: notifications),
      ),
    ),
  );
}
