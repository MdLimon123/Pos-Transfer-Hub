import 'notification_service.dart';


class ForegroundTransferService {
  ForegroundTransferService(this._notifications);

  final NotificationService _notifications;
  bool _running = false;
  String _lastBody = '';

  Future<void> sync({required int pending, required int running}) async {
    try {
      if (pending > 0) {
        final body = running > 0
            ? '$running active, ${pending - running} waiting'
            : 'Waiting for network to resume $pending transfer${pending == 1 ? '' : 's'}';
        if (!_running) {
          _running = true;
          _lastBody = body;
          await _notifications.startForeground(body);
        } else if (body != _lastBody) {
          _lastBody = body;
          await _notifications.updateForeground(body);
        }
      } else if (_running) {
        _running = false;
        await _notifications.stopForeground();
      }
    } catch (_) {
    
      _running = false;
    }
  }
}
