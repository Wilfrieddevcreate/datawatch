// Captures des écrans pour la vidéo de présentation.
//
//   python3 tool/promo/make_icons.py
//   flutter test tool/promo/capture_test.dart --update-goldens
//
// Écrans hauts (on les fait défiler dans la vidéo), barre d'état réservée en
// haut, icônes monogrammes. Sortie : tool/promo/assets/screens/.

import 'dart:io';

import 'package:datawatch/app/app.dart';
import 'package:datawatch/app/app_controller.dart';
import 'package:datawatch/core/units.dart';
import 'package:datawatch/data/plan_store.dart';
import 'package:datawatch/data/settings_store.dart';
import 'package:datawatch/domain/data_plan.dart';
import 'package:datawatch/ui/motion.dart';
import 'package:datawatch/ui/widgets/usage_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screenshots/fake_device_services.dart';
import '../screenshots/fake_usage_source.dart';

const _go = DataUnits.bytesPerGo;
final _now = DateTime(2026, 10, 19, 14, 26);
final _iconDir = '${Directory.current.path}/tool/promo/assets/icons';

DataPlan _plan() => DataPlan(
  operator: Operator.mtn,
  volumeBytes: 5 * _go,
  start: DateTime(2026, 10, 15, 8, 30),
  end: DateTime(2026, 10, 22, 8, 30),
);

Future<void> _loadFonts() async {
  Future<void> load(String family, Future<ByteData> data) async {
    final loader = FontLoader(family)..addFont(data);
    await loader.load();
  }

  await load(
    'Bricolage',
    rootBundle.load('assets/fonts/BricolageGrotesque.ttf'),
  );
  await load('Geist', rootBundle.load('assets/fonts/Geist.ttf'));
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (root != null && icons.existsSync()) {
    await load(
      'MaterialIcons',
      Future.value(ByteData.sublistView(icons.readAsBytesSync())),
    );
  }
}

Future<void> _capture(
  WidgetTester tester,
  String name, {
  DataPlan? plan,
  int? mobileBytes,
  Brightness brightness = Brightness.light,
  double height = 800,
  Future<void> Function(WidgetTester)? before,
}) async {
  tester.view.physicalSize = Size(720, height * 2);
  tester.view.devicePixelRatio = 2;
  // 28 dp réservés à la barre d'état, dessinée par la vidéo.
  tester.view.padding = const FakeViewPadding(top: 56);
  tester.view.viewPadding = const FakeViewPadding(top: 56);
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final controller = AppController(
    source: FakeUsageSource(
      mobileBytes: mobileBytes ?? (3.62 * _go).round(),
      iconDir: _iconDir,
    ),
    services: FakeDeviceServices(),
    store: MemoryPlanStore(plan),
    settingsStore: MemorySettingsStore(),
    clock: () => _now,
  );
  await tester.pumpWidget(
    DataWatchApp(key: UniqueKey(), controller: controller),
  );
  await tester.pumpAndSettle();
  if (before != null) {
    await before(tester);
    await tester.pumpAndSettle();
  }
  // Le décodage des icônes PNG se fait hors du temps simulé des tests.
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('assets/screens/$name.png'),
  );
}

void main() {
  DwMotion.enabled = false;
  setUpAll(_loadFonts);
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(UsageOwnerIcon.clearCache);

  testWidgets(
    'accueil',
    (t) => _capture(t, 'home', plan: _plan(), height: 1500),
  );
  testWidgets(
    'accueil sombre, alerte',
    (t) => _capture(
      t,
      'home_dark',
      plan: _plan(),
      mobileBytes: (4.12 * _go).round(),
      brightness: Brightness.dark,
    ),
  );
  testWidgets(
    'applications',
    (t) => _capture(
      t,
      'apps',
      plan: _plan(),
      height: 1400,
      before: (t) => t.tap(find.text('Applis')),
    ),
  );
  testWidgets(
    'détail',
    (t) => _capture(
      t,
      'detail',
      plan: _plan(),
      height: 1500,
      before: (t) async {
        await t.tap(find.text('Applis'));
        await t.pumpAndSettle();
        await t.tap(find.text('TikTok'));
      },
    ),
  );
  testWidgets(
    'forfait',
    (t) => _capture(
      t,
      'plan',
      plan: _plan(),
      height: 2000,
      before: (t) => t.tap(find.text('Forfait').last),
    ),
  );
  testWidgets(
    'conseils',
    (t) => _capture(
      t,
      'tips',
      plan: _plan(),
      height: 1400,
      before: (t) => t.tap(find.text('Conseils')),
    ),
  );
}
