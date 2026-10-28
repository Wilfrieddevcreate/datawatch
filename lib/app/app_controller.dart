import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/units.dart';
import '../data/device_services.dart';
import '../data/plan_store.dart';
import '../data/settings_store.dart';
import '../data/usage_source.dart';
import '../domain/data_plan.dart';

enum UsagePeriod {
  today('Aujourd’hui'),
  week('7 jours'),
  month('Ce mois'),
  plan('Forfait');

  const UsagePeriod(this.label);
  final String label;
}

class DateRange {
  const DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  Duration get length => end.difference(start);
}

/// Statistiques d'une période, telles que mesurées par Android.
class UsageSnapshot {
  const UsageSnapshot({
    required this.period,
    required this.range,
    required this.totals,
    required this.mobileApps,
    required this.wifiApps,
    required this.fetchedAt,
    this.previousMobile,
    this.previousWifi,
    this.screenTime,
  });

  final UsagePeriod period;
  final DateRange range;
  final DeviceTotals totals;
  final List<AppUsage> mobileApps;
  final List<AppUsage> wifiApps;
  final DateTime fetchedAt;

  /// Consommation par application sur la période précédente comparable
  /// (clé : [AppUsage.key]). Null si Android ne l'a pas fournie.
  final Map<String, int>? previousMobile;
  final Map<String, int>? previousWifi;

  /// Temps d'écran de la période par nom de paquet. Null si Android ne l'a
  /// pas fourni.
  final Map<String, Duration>? screenTime;

  Duration? screenTimeOf(AppUsage app) =>
      app.packageName == null ? null : screenTime?[app.packageName];

  /// Toutes les données d'une application (mobile et Wi-Fi) sur la période.
  int totalBytesOf(AppUsage app) {
    int bytesIn(List<AppUsage> list) {
      for (final a in list) {
        if (a.key == app.key) return a.bytes;
      }
      return 0;
    }

    return bytesIn(mobileApps) + bytesIn(wifiApps);
  }

  /// Données consommées par heure passée dans l'application.
  int? perHourOf(AppUsage app) {
    final time = screenTimeOf(app);
    return time == null ? null : bytesPerHour(totalBytesOf(app), time);
  }

  /// Évolution d'une application par rapport à la période précédente.
  double? variationOf(AppUsage app, NetworkKind network) {
    final previous = network == NetworkKind.mobile
        ? previousMobile
        : previousWifi;
    return variation(app.bytes, previous?[app.key]);
  }

  /// Total affiché pour un réseau : le compteur de l'appareil, ou la somme
  /// des applications s'il manque.
  int totalFor(NetworkKind network) {
    final apps = network == NetworkKind.mobile ? mobileApps : wifiApps;
    final sum = apps.fold<int>(0, (s, a) => s + a.bytes);
    final device = network == NetworkKind.mobile
        ? totals.mobileBytes
        : totals.wifiBytes;
    return device != null && device >= sum ? device : sum;
  }
}

/// Données par heure d'utilisation. Null sous [minTime] d'écran : quelques
/// minutes ne suffisent pas à estimer un rythme.
int? bytesPerHour(
  int bytes,
  Duration time, {
  Duration minTime = const Duration(minutes: 10),
}) {
  if (time < minTime || bytes <= 0) return null;
  return (bytes * Duration.millisecondsPerHour / time.inMilliseconds).round();
}

/// Variation relative entre deux volumes. Null quand la référence est trop
/// faible pour être parlante (moins de 1 Mo) : on n'affiche pas « +5000 % ».
double? variation(int current, int? previous) {
  if (previous == null || previous < DataUnits.bytesPerMo) return null;
  return (current - previous) / previous;
}

/// Période comparable qui précède [range] : la veille à la même heure, les
/// 7 jours d'avant, le même nombre de jours du mois précédent, ou la même
/// durée avant le début du forfait.
DateRange? previousRangeFor(UsagePeriod period, DateRange range) {
  if (range.length <= Duration.zero) return null;
  DateTime shiftDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day - days, d.hour, d.minute, d.second);
  switch (period) {
    case UsagePeriod.today:
      return DateRange(shiftDays(range.start, 1), shiftDays(range.end, 1));
    case UsagePeriod.week:
      return DateRange(shiftDays(range.start, 7), shiftDays(range.end, 7));
    case UsagePeriod.month:
      final end = range.end;
      final lastDayOfPrevious = DateTime(end.year, end.month, 0).day;
      return DateRange(
        DateTime(end.year, end.month - 1),
        DateTime(
          end.year,
          end.month - 1,
          end.day.clamp(1, lastDayOfPrevious),
          end.hour,
          end.minute,
        ),
      );
    case UsagePeriod.plan:
      return DateRange(range.start.subtract(range.length), range.start);
  }
}

enum AccessState { unknown, denied, granted }

/// Paquet de DataWatch, pour ouvrir sa propre page dans les paramètres Android.
const appPackageName = 'net.alopro.datawatch';

/// Coordonnées de l'éditeur, affichées dans les paramètres et la politique
/// de confidentialité.
const publisherEmail = 'hello@alopro.net';
const publisherSite = 'alopro.net';

class AppController extends ChangeNotifier {
  AppController({
    this._source = const UsageSource(),
    this._services = const DeviceServices(),
    PlanStore? store,
    SettingsStore? settingsStore,
    DateTime Function()? clock,
  }) : _store = store ?? PrefsPlanStore(),
       _settingsStore = settingsStore ?? PrefsSettingsStore(),
       _clock = clock ?? DateTime.now;

  final UsageSource _source;
  final DeviceServices _services;
  final PlanStore _store;
  final SettingsStore _settingsStore;
  final DateTime Function() _clock;

  AccessState access = AccessState.unknown;

  /// « Accès aux données d'utilisation » accordé.
  bool usageAccessGranted = false;

  /// Android 9 et avant : l'autorisation « Téléphone » manque encore.
  bool phonePermissionNeeded = false;
  DataPlan? plan;
  AppSettings settings = const AppSettings();
  DeviceStatus device = const DeviceStatus();
  UsagePeriod period = UsagePeriod.plan;
  UsageSnapshot? snapshot;

  /// Consommation mobile depuis le début du forfait. Null sans forfait, ou
  /// quand Android ne fournit pas la mesure.
  PlanUsage? planUsage;
  bool loading = false;
  Object? error;

  int _requestId = 0;

  UsageSource get source => _source;
  DateTime now() => _clock();

  /// Période réellement affichée : « Forfait » n'existe que si un forfait est déclaré.
  UsagePeriod get effectivePeriod =>
      period == UsagePeriod.plan && plan == null ? UsagePeriod.week : period;

  /// Les alertes peuvent-elles réellement s'afficher ?
  bool get alertsActive =>
      settings.notificationsEnabled && device.notificationsAllowed;

  Future<void> init() async {
    var restored = true;
    try {
      plan = await _store.load().timeout(_readTimeout);
      settings = await _settingsStore.load().timeout(_readTimeout);
      displayUnits = settings.units;
    } catch (e) {
      // Stockage illisible : on démarre sans forfait plutôt que de rester sur
      // un écran vide, et on ne touche pas aux alertes déjà planifiées.
      restored = false;
      debugPrint('DataWatch : stockage local illisible au lancement ($e)');
    }
    if (restored) await _syncAlerts();
    await recheckAccess();
  }

  static const _readTimeout = Duration(seconds: 5);

  /// À appeler au lancement et à chaque retour au premier plan : l'accès et
  /// les autorisations ont pu changer dans les paramètres Android.
  Future<void> recheckAccess() async {
    usageAccessGranted = await _guardDevice(
      _source.hasUsageAccess,
      fallback: false,
    );
    phonePermissionNeeded = await _guardDevice(
      _services.phonePermissionNeeded,
      fallback: false,
    );
    final granted = usageAccessGranted && !phonePermissionNeeded;
    access = granted ? AccessState.granted : AccessState.denied;
    notifyListeners();
    await refreshDeviceStatus();
    if (granted) await refresh();
  }

  /// Android 9 et avant : demande l'autorisation « Téléphone ». Si Android ne
  /// l'affiche plus (refus définitif), ouvre la page de l'application.
  Future<void> requestPhonePermission() async {
    final granted = await _guardDevice(
      _services.requestPhonePermission,
      fallback: false,
    );
    if (!granted) {
      await _guardDevice(
        () => _services.openAppSettings(appPackageName),
        fallback: null,
      );
    }
    await recheckAccess();
  }

  Future<void> openUrl(String url) =>
      _guardDevice(() => _services.openUrl(url), fallback: null);

  Future<void> refreshDeviceStatus() async {
    device = await _guardDevice(_services.status, fallback: device);
    notifyListeners();
  }

  Future<void> openUsageSettings() => _source.openUsageAccessSettings();
  Future<void> openNotificationSettings() =>
      _guardDevice(_services.openNotificationSettings, fallback: null);
  Future<void> openBatterySettings() =>
      _guardDevice(_services.openBatterySettings, fallback: null);
  Future<void> openAppSettings(String packageName) => _guardDevice(
    () => _services.openAppSettings(packageName),
    fallback: null,
  );

  /// Demande l'autorisation de notifier si besoin. Vrai si accordée.
  Future<bool> ensureNotificationPermission() async {
    if (device.notificationsAllowed) return true;
    await _guardDevice(
      _services.requestNotificationPermission,
      fallback: false,
    );
    await refreshDeviceStatus();
    return device.notificationsAllowed;
  }

  Future<void> setPeriod(UsagePeriod value) async {
    if (period == value) return;
    period = value;
    notifyListeners();
    await refresh();
  }

  Future<void> savePlan(DataPlan value) async {
    await _store.save(value);
    plan = value;
    period = UsagePeriod.plan;
    notifyListeners();
    await _syncAlerts();
    await refresh();
  }

  Future<void> clearPlan() async {
    await _store.clear();
    plan = null;
    planUsage = null;
    notifyListeners();
    await _syncAlerts();
    await refresh();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (enabled) await ensureNotificationPermission();
    await _saveSettings(settings.copyWith(notificationsEnabled: enabled));
  }

  Future<void> setUnits(UnitMode units) =>
      _saveSettings(settings.copyWith(units: units));

  /// Efface tout ce que DataWatch a enregistré sur le téléphone. Les
  /// statistiques d'Android, elles, ne sont pas touchées.
  Future<void> clearAllData() async {
    await _store.clear();
    await _settingsStore.clear();
    await _guardDevice(_services.clearAlerts, fallback: null);
    plan = null;
    planUsage = null;
    settings = const AppSettings();
    displayUnits = settings.units;
    period = UsagePeriod.plan;
    notifyListeners();
    await refresh();
  }

  Future<void> _saveSettings(AppSettings value) async {
    await _settingsStore.save(value);
    settings = value;
    displayUnits = value.units;
    notifyListeners();
    await _syncAlerts();
  }

  Future<void> _syncAlerts() => _guardDevice(
    () => _services.configureAlerts(plan: plan, settings: settings),
    fallback: null,
  );

  DateRange rangeFor(UsagePeriod p, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (p) {
      UsagePeriod.today => DateRange(today, now),
      UsagePeriod.week => DateRange(
        DateTime(now.year, now.month, now.day - 6),
        now,
      ),
      UsagePeriod.month => DateRange(DateTime(now.year, now.month), now),
      UsagePeriod.plan =>
        plan == null
            ? DateRange(DateTime(now.year, now.month, now.day - 6), now)
            : DateRange(plan!.start, plan!.measuredUntil(now)),
    };
  }

  Future<void> refresh() async {
    if (access != AccessState.granted) return;
    final id = ++_requestId;
    loading = true;
    error = null;
    notifyListeners();

    final now = _clock();
    final shown = effectivePeriod;
    final range = rangeFor(shown, now);
    final currentPlan = plan;
    try {
      // Forfait qui démarre à l'instant : rien à mesurer encore.
      if (!range.end.isAfter(range.start)) {
        snapshot = UsageSnapshot(
          period: shown,
          range: range,
          totals: const DeviceTotals(mobileBytes: 0, wifiBytes: 0),
          mobileApps: const [],
          wifiApps: const [],
          fetchedAt: now,
        );
        planUsage = currentPlan?.usage(0);
        return;
      }
      final planRange = currentPlan == null
          ? null
          : DateRange(currentPlan.start, currentPlan.measuredUntil(now));
      final queryPlanSeparately =
          planRange != null &&
          shown != UsagePeriod.plan &&
          planRange.end.isAfter(planRange.start);

      // La période précédente est un bonus : son échec ne bloque pas l'écran.
      final previous = previousRangeFor(shown, range);
      final previousMobile = previous == null
          ? Future<Map<String, int>?>.value()
          : _keyed(
              _source.appUsage(
                NetworkKind.mobile,
                previous.start,
                previous.end,
              ),
            );
      final previousWifi = previous == null
          ? Future<Map<String, int>?>.value()
          : _keyed(
              _source.appUsage(NetworkKind.wifi, previous.start, previous.end),
            );

      final results = await Future.wait([
        _source.deviceTotals(range.start, range.end),
        _source.appUsage(NetworkKind.mobile, range.start, range.end),
        _source.appUsage(NetworkKind.wifi, range.start, range.end),
        if (queryPlanSeparately)
          _source.deviceTotals(planRange.start, planRange.end),
      ]);
      final previousResults = await Future.wait([previousMobile, previousWifi]);
      final screenTime = await _source
          .screenTime(range.start, range.end)
          .then<Map<String, Duration>?>((m) => m)
          .catchError((Object _) => null);
      if (id != _requestId) return;

      final totals = results[0] as DeviceTotals;
      snapshot = UsageSnapshot(
        period: shown,
        range: range,
        totals: totals,
        mobileApps: results[1] as List<AppUsage>,
        wifiApps: results[2] as List<AppUsage>,
        fetchedAt: now,
        previousMobile: previousResults[0],
        previousWifi: previousResults[1],
        screenTime: screenTime,
      );
      if (currentPlan == null) {
        planUsage = null;
      } else if (queryPlanSeparately) {
        final used = (results[3] as DeviceTotals).mobileBytes;
        planUsage = used == null ? null : currentPlan.usage(used);
      } else if (shown == UsagePeriod.plan) {
        final used = totals.mobileBytes;
        planUsage = used == null ? null : currentPlan.usage(used);
      } else {
        // Le forfait démarre à l'instant.
        planUsage = currentPlan.usage(0);
      }
      // Un seuil a pu être franchi pendant que l'application était ouverte.
      if (planUsage != null) {
        unawaited(_guardDevice(_services.checkAlertsNow, fallback: null));
      }
    } on UsageAccessDenied {
      if (id != _requestId) return;
      access = AccessState.denied;
    } catch (e) {
      if (id != _requestId) return;
      error = e;
    } finally {
      if (id == _requestId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  static Future<Map<String, int>?> _keyed(Future<List<AppUsage>> apps) => apps
      .then<Map<String, int>?>((list) => {for (final a in list) a.key: a.bytes})
      .catchError((Object _) => null);

  /// Les services système ne doivent jamais faire échouer un écran.
  static Future<T> _guardDevice<T>(
    Future<T> Function() call, {
    required T fallback,
  }) async {
    try {
      return await call();
    } on PlatformException {
      return fallback;
    } on MissingPluginException {
      return fallback;
    }
  }
}
