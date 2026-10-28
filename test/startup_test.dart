import 'dart:async';

import 'package:datawatch/app/app_controller.dart';
import 'package:datawatch/data/plan_store.dart';
import 'package:datawatch/data/settings_store.dart';
import 'package:datawatch/domain/data_plan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/screenshots/fake_device_services.dart';
import '../tool/screenshots/fake_usage_source.dart';

/// Stockage qui échoue, comme shared_preferences_android 2.5.0 en release.
class _BrokenPlanStore implements PlanStore {
  @override
  Future<DataPlan?> load() => Future.error(StateError('JNI indisponible'));
  @override
  Future<void> save(DataPlan plan) async {}
  @override
  Future<void> clear() async {}
}

/// Stockage qui ne répond jamais.
class _StuckPlanStore implements PlanStore {
  @override
  Future<DataPlan?> load() => Completer<DataPlan?>().future;
  @override
  Future<void> save(DataPlan plan) async {}
  @override
  Future<void> clear() async {}
}

AppController _controller(PlanStore store, {bool granted = true}) =>
    AppController(
      source: FakeUsageSource(granted: granted),
      services: FakeDeviceServices(),
      store: store,
      settingsStore: MemorySettingsStore(),
      clock: () => DateTime(2026, 10, 28, 12),
    );

void main() {
  group('le lancement ne reste jamais sur un écran vide', () {
    test('stockage en erreur : accueil sans forfait', () async {
      final controller = _controller(_BrokenPlanStore());
      await controller.init();
      expect(controller.access, AccessState.granted);
      expect(controller.plan, isNull);
    });

    test('stockage en erreur, accès non accordé : présentation', () async {
      final controller = _controller(_BrokenPlanStore(), granted: false);
      await controller.init();
      expect(controller.access, AccessState.denied);
    });

    testWidgets('stockage bloqué : on repart après le délai', (tester) async {
      final controller = _controller(_StuckPlanStore());
      unawaited(controller.init());
      await tester.pump(const Duration(seconds: 6));
      expect(controller.access, AccessState.granted);
    });
  });
}
