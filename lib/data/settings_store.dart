import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';

/// Préférences de l'utilisateur, conservées sur le téléphone.
class AppSettings {
  const AppSettings({
    this.notificationsEnabled = true,
    this.units = UnitMode.auto,
  });

  /// Alertes de consommation activées dans DataWatch.
  final bool notificationsEnabled;
  final UnitMode units;

  AppSettings copyWith({bool? notificationsEnabled, UnitMode? units}) =>
      AppSettings(
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        units: units ?? this.units,
      );
}

abstract interface class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
  Future<void> clear();
}

class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _notifications = 'settings.notifications';
  static const _units = 'settings.units';
  final SharedPreferencesAsync _prefs;

  @override
  Future<AppSettings> load() async {
    final notifications = await _prefs.getBool(_notifications);
    final units = await _prefs.getString(_units);
    return AppSettings(
      notificationsEnabled: notifications ?? true,
      units: UnitMode.values.firstWhere(
        (u) => u.name == units,
        orElse: () => UnitMode.auto,
      ),
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_notifications, settings.notificationsEnabled);
    await _prefs.setString(_units, settings.units.name);
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_notifications);
    await _prefs.remove(_units);
  }
}

class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this._settings = const AppSettings()]);
  AppSettings _settings;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;

  @override
  Future<void> clear() async => _settings = const AppSettings();
}
