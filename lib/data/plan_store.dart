import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/data_plan.dart';

/// Persistance locale du forfait. Rien ne quitte le téléphone.
abstract interface class PlanStore {
  Future<DataPlan?> load();
  Future<void> save(DataPlan plan);
  Future<void> clear();
}

class PrefsPlanStore implements PlanStore {
  PrefsPlanStore([SharedPreferencesAsync? prefs]) : _prefs = prefs ?? SharedPreferencesAsync();

  static const _key = 'plan.v1';
  final SharedPreferencesAsync _prefs;

  @override
  Future<DataPlan?> load() async {
    final raw = await _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return DataPlan.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(DataPlan plan) => _prefs.setString(_key, jsonEncode(plan.toJson()));

  @override
  Future<void> clear() => _prefs.remove(_key);
}

class MemoryPlanStore implements PlanStore {
  MemoryPlanStore([this._plan]);
  DataPlan? _plan;

  @override
  Future<DataPlan?> load() async => _plan;

  @override
  Future<void> save(DataPlan plan) async => _plan = plan;

  @override
  Future<void> clear() async => _plan = null;
}
