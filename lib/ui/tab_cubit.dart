import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/notification_service.dart';

/// Which bottom-navigation tab is shown. Also driven by notification taps and
/// the global transfers banner.
class TabCubit extends Cubit<int> {
  TabCubit({int initial = 0}) : super(initial);

  static const upload = 0;
  static const files = 1;
  static const transfers = 2;
  static const profile = 3;

  void select(int index) => emit(index);

  static int fromPayload(String? payload) => switch (payload) {
        NotificationPayload.files => files,
        NotificationPayload.transfers => transfers,
        _ => upload,
      };
}
