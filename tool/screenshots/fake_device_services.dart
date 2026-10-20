import 'package:datawatch/data/device_services.dart';
import 'package:datawatch/data/settings_store.dart';
import 'package:datawatch/domain/data_plan.dart';

/// Services système factices pour les captures d'écran.
class FakeDeviceServices implements DeviceServices {
  FakeDeviceServices({
    this.notificationsAllowed = true,
    this.backgroundUnrestricted = false,
    this.phoneNeeded = false,
  });

  bool notificationsAllowed;
  bool backgroundUnrestricted;

  /// Simule Android 9 sans l'autorisation « Téléphone ».
  bool phoneNeeded;

  @override
  Future<DeviceStatus> status() async => DeviceStatus(
    notificationsAllowed: notificationsAllowed,
    backgroundUnrestricted: backgroundUnrestricted,
    appVersion: '1.0.0 (1)',
  );

  @override
  Future<bool> requestNotificationPermission() async => notificationsAllowed;

  @override
  Future<bool> phonePermissionNeeded() async => phoneNeeded;

  @override
  Future<bool> requestPhonePermission() async => true;

  @override
  Future<void> openUrl(String url) async {}

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> openBatterySettings() async {}

  @override
  Future<void> openAppSettings(String packageName) async {}

  @override
  Future<void> configureAlerts({
    required DataPlan? plan,
    required AppSettings settings,
  }) async {}

  @override
  Future<void> checkAlertsNow() async {}

  @override
  Future<void> clearAlerts() async {}
}
