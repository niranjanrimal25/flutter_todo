import 'package:flutter/foundation.dart';

import '../models/quiet_hours.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class QuietHoursProvider extends ChangeNotifier {
  QuietHoursSettings _settings = const QuietHoursSettings();

  QuietHoursSettings get settings => _settings;
  bool get enabled => _settings.enabled;
  bool get isActiveNow => _settings.isActiveAt(DateTime.now());

  Future<void> load() async {
    final enabled = await StorageService.getAppState('quietHours.enabled');
    final start = await StorageService.getAppState('quietHours.startMinutes');
    final end = await StorageService.getAppState('quietHours.endMinutes');

    _settings = QuietHoursSettings(
      enabled: enabled == 'true',
      startMinutes: int.tryParse(start ?? '') ??
          QuietHoursSettings.defaultStartMinutes,
      endMinutes: int.tryParse(end ?? '') ??
          QuietHoursSettings.defaultEndMinutes,
    );
    notifyListeners();
    await NotificationService.setQuietHours(_settings);
  }

  Future<void> update(QuietHoursSettings settings) async {
    _settings = settings;
    notifyListeners();

    await Future.wait([
      StorageService.saveAppState(
        'quietHours.enabled',
        settings.enabled.toString(),
      ),
      StorageService.saveAppState(
        'quietHours.startMinutes',
        settings.startMinutes.toString(),
      ),
      StorageService.saveAppState(
        'quietHours.endMinutes',
        settings.endMinutes.toString(),
      ),
    ]);
    await NotificationService.setQuietHours(settings);
  }
}
