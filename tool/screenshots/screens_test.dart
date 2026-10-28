// Captures d'écran de l'application, sans téléphone.
//
//   flutter test tool/screenshots/screens_test.dart --update-goldens
//
// Les images sont écrites dans tool/screenshots/out/ (ignoré par git).
// Hors du dossier test/ : `flutter test` ne les compare pas d'une machine à l'autre.

import 'dart:io';

import 'package:datawatch/app/app.dart';
import 'package:datawatch/app/app_controller.dart';
import 'package:datawatch/core/units.dart';
import 'package:datawatch/data/plan_store.dart';
import 'package:datawatch/data/settings_store.dart';
import 'package:datawatch/domain/data_plan.dart';
import 'package:datawatch/ui/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_device_services.dart';
import 'fake_usage_source.dart';

const _go = DataUnits.bytesPerGo;
final _now = DateTime(2026, 10, 19, 14, 26);

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

/// Rend l'application et enregistre la capture `name`.
Future<void> _shoot(
  WidgetTester tester,
  String name, {
  DataPlan? plan,
  int? mobileBytes,
  bool granted = true,
  Brightness brightness = Brightness.light,
  double height = 800,
  double textScale = 1,
  bool notificationsAllowed = true,
  bool phoneNeeded = false,
  Future<void> Function(WidgetTester)? before,
}) async {
  tester.view.physicalSize = Size(720, height * 2);
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final controller = AppController(
    source: FakeUsageSource(
      mobileBytes: mobileBytes ?? (3.62 * _go).round(),
      granted: granted,
    ),
    services: FakeDeviceServices(
      notificationsAllowed: notificationsAllowed,
      phoneNeeded: phoneNeeded,
    ),
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
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

void main() {
  DwMotion.enabled = false;
  setUpAll(_loadFonts);

  testWidgets('accueil sans forfait', (t) => _shoot(t, 'accueil_sans_forfait'));
  testWidgets(
    'accueil avec forfait',
    (t) => _shoot(t, 'accueil_forfait', plan: _plan()),
  );
  testWidgets(
    'accueil avec forfait, page entière',
    (t) => _shoot(t, 'accueil_forfait_long', plan: _plan(), height: 1500),
  );
  testWidgets(
    'accueil avec forfait, texte agrandi',
    (t) =>
        _shoot(t, 'accueil_forfait_texte115', plan: _plan(), textScale: 1.15),
  );
  testWidgets(
    'accueil alerte 80 %, sombre',
    (t) => _shoot(
      t,
      'accueil_alerte_sombre',
      plan: _plan(),
      mobileBytes: (4.12 * _go).round(),
      brightness: Brightness.dark,
    ),
  );
  testWidgets(
    'accueil forfait vide',
    (t) => _shoot(t, 'accueil_forfait_neuf', plan: _plan(), mobileBytes: 0),
  );
  testWidgets('autorisation', (t) => _shoot(t, 'autorisation', granted: false));
  testWidgets(
    'applications',
    (t) => _shoot(
      t,
      'applications',
      plan: _plan(),
      before: (t) => t.tap(find.text('Applis')),
    ),
  );
  testWidgets(
    'applications par coût par heure',
    (t) => _shoot(
      t,
      'applications_cout_heure',
      plan: _plan(),
      before: (t) async {
        await t.tap(find.text('Applis'));
        await t.pumpAndSettle();
        await t.tap(find.text('Plus gourmandes'));
      },
    ),
  );
  testWidgets(
    'forfait',
    (t) => _shoot(
      t,
      'forfait',
      plan: _plan(),
      before: (t) => t.tap(find.text('Forfait').last),
    ),
  );
  testWidgets(
    'conseils',
    (t) => _shoot(
      t,
      'conseils',
      plan: _plan(),
      before: (t) => t.tap(find.text('Conseils')),
    ),
  );
  testWidgets(
    'détail d’une application',
    (t) => _shoot(
      t,
      'detail_application',
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
    'paramètres',
    (t) => _shoot(
      t,
      'parametres',
      plan: _plan(),
      height: 1700,
      before: (t) => t.tap(find.byTooltip('Paramètres').first),
    ),
  );
  testWidgets(
    'mesure expliquée',
    (t) => _shoot(
      t,
      'info_mesure',
      plan: _plan(),
      height: 1400,
      before: (t) async {
        await t.tap(find.byTooltip('Paramètres').first);
        await t.pumpAndSettle();
        await t.tap(find.text('Comment la mesure fonctionne'));
      },
    ),
  );
  testWidgets(
    'forfait, seuils et notifications bloquées',
    (t) => _shoot(
      t,
      'forfait_seuils',
      plan: _plan().copyWith(thresholds: DataPlan.everyTwentyThresholds),
      height: 2000,
      notificationsAllowed: false,
      before: (t) => t.tap(find.text('Forfait').last),
    ),
  );
  testWidgets(
    'autorisation Téléphone (Android 9)',
    (t) => _shoot(t, 'autorisation_telephone', phoneNeeded: true),
  );
  testWidgets(
    'politique de confidentialité',
    (t) => _shoot(
      t,
      'confidentialite',
      plan: _plan(),
      height: 2200,
      before: (t) async {
        await t.tap(find.byTooltip('Paramètres').first);
        await t.pumpAndSettle();
        await t.tap(find.text('Politique de confidentialité'));
      },
    ),
  );
}
