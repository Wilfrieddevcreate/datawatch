import 'package:flutter/services.dart';

import '../domain/data_plan.dart';
import 'settings_store.dart';

/// État des autorisations dont dépendent les alertes.
class DeviceStatus {
  const DeviceStatus({
    this.notificationsAllowed = true,
    this.backgroundUnrestricted = true,
    this.appVersion,
  });

  /// Android autorise DataWatch à afficher des notifications.
  final bool notificationsAllowed;

  /// Android ne limite pas DataWatch en arrière-plan : alertes à l'heure.
  final bool backgroundUnrestricted;
  final String? appVersion;
}

/// Accès au système hors statistiques : permissions, écrans de réglages,
/// alertes en arrière-plan (canal Kotlin `device`).
class DeviceServices {
  const DeviceServices();

  static const MethodChannel _channel = MethodChannel(
    'net.alopro.datawatch/device',
  );

  Future<DeviceStatus> status() async {
    final results = await Future.wait([
      _channel.invokeMethod<bool>('notificationsAllowed'),
      _channel.invokeMethod<bool>('backgroundUnrestricted'),
      _channel.invokeMethod<String>('appVersion'),
    ]);
    return DeviceStatus(
      notificationsAllowed: results[0] as bool? ?? false,
      backgroundUnrestricted: results[1] as bool? ?? false,
      appVersion: results[2] as String?,
    );
  }

  /// Affiche la demande système (Android 13+). Vrai si les notifications
  /// sont autorisées à l'issue de la demande.
  Future<bool> requestNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>(
            'requestNotificationPermission',
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openNotificationSettings() =>
      _channel.invokeMethod('openNotificationSettings');

  Future<void> openBatterySettings() =>
      _channel.invokeMethod('openBatterySettings');

  /// Page Android d'une application (données mobiles, arrière-plan…).
  Future<void> openAppSettings(String packageName) =>
      _channel.invokeMethod('openAppSettings', {'packageName': packageName});

  /// Recopie le forfait et les réglages pour la vérification en arrière-plan.
  Future<void> configureAlerts({
    required DataPlan? plan,
    required AppSettings settings,
  }) {
    return _channel.invokeMethod('configureAlerts', {
      'enabled': settings.notificationsEnabled && plan != null,
      'start': plan?.start.millisecondsSinceEpoch ?? 0,
      'end': plan?.end.millisecondsSinceEpoch ?? 0,
      'volumeBytes': plan?.volumeBytes ?? 0,
      'thresholds': (plan?.thresholds.toList() ?? <int>[])..sort(),
      'units': settings.units.name,
    });
  }

  /// Vérifie les seuils tout de suite (après une actualisation).
  Future<void> checkAlertsNow() => _channel.invokeMethod('checkAlertsNow');

  /// Oublie la configuration et l'historique des alertes.
  Future<void> clearAlerts() => _channel.invokeMethod('clearAlerts');
}
