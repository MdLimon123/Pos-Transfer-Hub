import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/notification_service.dart';
import 'features/auth/auth_cubit.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/login_page.dart';
import 'ui/tab_cubit.dart';
import 'ui/widgets/transfer_banner.dart';

class TransferHubApp extends StatefulWidget {
  const TransferHubApp({super.key, required this.notifications});

  final NotificationService notifications;

  @override
  State<TransferHubApp> createState() => _TransferHubAppState();
}

class _TransferHubAppState extends State<TransferHubApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    // Notification tapped while the app is alive (foreground or background).
    _taps = widget.notifications.taps.listen((payload) {
      if (!mounted) return;
      _navigatorKey.currentState?.popUntil((r) => r.isFirst);
      context.read<TabCubit>().select(TabCubit.fromPayload(payload));
    });
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transfer Hub',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E6E)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0x22000000)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0B6E6E), brightness: Brightness.dark),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      // The banner lives here, above the Navigator, so it is visible on every route.
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          TransferBanner(navigatorKey: _navigatorKey),
        ],
      ),
      home: BlocBuilder<AuthCubit, AuthState>(
        buildWhen: (a, b) => a.status != b.status,
        builder: (context, state) => switch (state.status) {
          AuthStatus.unknown => const Scaffold(body: Center(child: CircularProgressIndicator())),
          AuthStatus.unauthenticated => const LoginPage(),
          AuthStatus.authenticated => const HomePage(),
        },
      ),
    );
  }
}
