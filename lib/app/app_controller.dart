import 'package:flutter/foundation.dart';

import '../data/plan_store.dart';
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
  });

  final UsagePeriod period;
  final DateRange range;
  final DeviceTotals totals;
  final List<AppUsage> mobileApps;
  final List<AppUsage> wifiApps;
  final DateTime fetchedAt;
}

enum AccessState { unknown, denied, granted }

class AppController extends ChangeNotifier {
  AppController({
    this._source = const UsageSource(),
    PlanStore? store,
    DateTime Function()? clock,
  })  : _store = store ?? PrefsPlanStore(),
        _clock = clock ?? DateTime.now;

  final UsageSource _source;
  final PlanStore _store;
  final DateTime Function() _clock;

  AccessState access = AccessState.unknown;
  DataPlan? plan;
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

  Future<void> init() async {
    plan = await _store.load();
    await recheckAccess();
  }

  /// À appeler au lancement et à chaque retour au premier plan (l'accès a pu
  /// être accordé ou retiré dans les paramètres Android).
  Future<void> recheckAccess() async {
    final granted = await _source.hasUsageAccess();
    access = granted ? AccessState.granted : AccessState.denied;
    notifyListeners();
    if (granted) await refresh();
  }

  Future<void> openUsageSettings() => _source.openUsageAccessSettings();

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
    await refresh();
  }

  Future<void> clearPlan() async {
    await _store.clear();
    plan = null;
    planUsage = null;
    notifyListeners();
    await refresh();
  }

  DateRange rangeFor(UsagePeriod p, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (p) {
      UsagePeriod.today => DateRange(today, now),
      UsagePeriod.week => DateRange(today.subtract(const Duration(days: 6)), now),
      UsagePeriod.month => DateRange(DateTime(now.year, now.month), now),
      UsagePeriod.plan => plan == null
          ? DateRange(today.subtract(const Duration(days: 6)), now)
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
      final results = await Future.wait([
        _source.deviceTotals(range.start, range.end),
        _source.appUsage(NetworkKind.mobile, range.start, range.end),
        _source.appUsage(NetworkKind.wifi, range.start, range.end),
        if (currentPlan != null && shown != UsagePeriod.plan)
          _source.deviceTotals(currentPlan.start, currentPlan.measuredUntil(now)),
      ]);
      if (id != _requestId) return;

      final totals = results[0] as DeviceTotals;
      snapshot = UsageSnapshot(
        period: shown,
        range: range,
        totals: totals,
        mobileApps: results[1] as List<AppUsage>,
        wifiApps: results[2] as List<AppUsage>,
        fetchedAt: now,
      );
      if (currentPlan == null) {
        planUsage = null;
      } else {
        final planTotals = results.length > 3 ? results[3] as DeviceTotals : totals;
        final used = planTotals.mobileBytes;
        planUsage = used == null ? null : currentPlan.usage(used);
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
}
