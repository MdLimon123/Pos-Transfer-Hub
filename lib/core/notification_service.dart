import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../features/transfers/models/transfer_task.dart';
import 'format.dart';


class NotificationPayload {
  const NotificationPayload._();
  static const files = 'files';
  static const transfers = 'transfers';
}

class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();


  String? launchPayload;


  Stream<String> get taps => _taps.stream;

  static const _serviceNotificationId = 1;
  static const _progressChannel = 'transfer_progress';
  static const _doneChannel = 'transfer_done';
  static const _serviceChannel = 'transfer_service';

  Future<void> init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _taps.add(payload);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      launchPayload = launch!.notificationResponse?.payload;
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  int _idFor(TransferTask t) => (t.id.hashCode & 0x3fffffff) + 100;

  String _verb(TransferTask t) => t.isUpload ? 'Uploading' : 'Downloading';

  Future<void> showProgress(TransferTask t) {
    final percent = t.percent;
    return _plugin.show(
      id: _idFor(t),
      title: '${_verb(t)} ${t.name}',
      body: t.totalBytes > 0
          ? '$percent%  •  ${formatBytes(t.transferredBytes)} of ${formatBytes(t.totalBytes)}'
          : 'Starting…',
      notificationDetails: NotificationDetails(
        iOS: const DarwinNotificationDetails(presentSound: false, presentBadge: false),
        android: AndroidNotificationDetails(
          _progressChannel,
          'Transfer progress',
          channelDescription: 'Live progress of uploads and downloads',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: 100,
          progress: percent,
          indeterminate: t.totalBytes <= 0,
          category: AndroidNotificationCategory.progress,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: NotificationPayload.transfers,
    );
  }


  Future<void> showState(TransferTask t, String title, String body) {
    return _plugin.show(
      id: _idFor(t),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(presentSound: false, presentBadge: false),
        android: AndroidNotificationDetails(
          _progressChannel,
          'Transfer progress',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: NotificationPayload.transfers,
    );
  }

 
  Future<void> showCompleted(TransferTask t) {
    return _plugin.show(
      id: _idFor(t),
      title: t.isUpload ? 'Upload complete' : 'Download complete',
      body: t.isUpload
          ? '${t.name} was uploaded. Tap to view your files.'
          : '${t.name} was saved to ${Platform.isIOS ? 'Files › Transfer Hub' : 'Downloads/TransferHub'}.',
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          _doneChannel,
          'Transfer results',
          channelDescription: 'Shown when an upload or download finishes',
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: t.isUpload ? NotificationPayload.files : NotificationPayload.transfers,
    );
  }

  Future<void> cancelFor(TransferTask t) => _plugin.cancel(id: _idFor(t));

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  AndroidNotificationDetails _serviceDetails() => const AndroidNotificationDetails(
        _serviceChannel,
        'Background transfers',
        channelDescription: 'Keeps transfers running while the app is in the background',
        importance: Importance.min,
        priority: Priority.min,
        ongoing: true,
        playSound: false,
        enableVibration: false,
        icon: '@mipmap/ic_launcher',
      );

  Future<void> startForeground(String body) async {
    await _android?.startForegroundService(
      id: _serviceNotificationId,
      title: 'Transfers in progress',
      body: body,
      notificationDetails: _serviceDetails(),
      payload: NotificationPayload.transfers,
      foregroundServiceTypes: {AndroidServiceForegroundType.foregroundServiceTypeDataSync},
    );
  }

  Future<void> updateForeground(String body) {
    return _plugin.show(
      id: _serviceNotificationId,
      title: 'Transfers in progress',
      body: body,
      notificationDetails: NotificationDetails(android: _serviceDetails()),
      payload: NotificationPayload.transfers,
    );
  }

  Future<void> stopForeground() async {
    await _android?.stopForegroundService();
  }
}
