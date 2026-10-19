import 'package:datawatch/core/units.dart';
import 'package:datawatch/data/usage_source.dart';
import 'package:datawatch/domain/data_plan.dart';
import 'package:datawatch/domain/tips.dart';
import 'package:datawatch/ui/screens/apps_screen.dart';
import 'package:datawatch/ui/screens/plan_screen.dart';
import 'package:flutter_test/flutter_test.dart';

const go = DataUnits.bytesPerGo;
const mo = DataUnits.bytesPerMo;

DataPlan plan({int volume = 5 * go}) => DataPlan(
      operator: Operator.mtn,
      volumeBytes: volume,
      start: DateTime(2026, 10, 15, 8, 30),
      end: DateTime(2026, 10, 22, 8, 30),
    );

void main() {
  group('PlanUsage', () {
    test('restant = volume − consommé', () {
      final u = plan().usage((3.62 * go).round());
      expect(u.remainingBytes, 5 * go - (3.62 * go).round());
      expect(u.usedFraction, closeTo(0.724, 0.001));
      expect(u.level, UsageLevel.half);
    });

    test('le restant ne descend jamais sous zéro', () {
      final u = plan().usage(6 * go);
      expect(u.remainingBytes, 0);
      expect(u.usedFraction, 1);
      expect(u.level, UsageLevel.exhausted);
    });

    test('niveaux d’alerte', () {
      expect(plan().usage(1 * go).level, UsageLevel.ok);
      expect(plan().usage((2.5 * go).round()).level, UsageLevel.half);
      expect(plan().usage(4 * go).level, UsageLevel.warning);
    });

    test('seuils franchis : 5 Go, 80 % = 4 Go', () {
      final p = plan();
      expect(p.usage(4 * go - 1).reachedThresholds(p.thresholds), [50]);
      expect(p.usage(4 * go).reachedThresholds(p.thresholds), [50, 80]);
    });
  });

  group('DataPlan', () {
    test('aller-retour JSON', () {
      final p = plan().copyWith(operator: Operator.moov, thresholds: {80}, recurring: true);
      final back = DataPlan.fromJson(p.toJson());
      expect(back.operator, Operator.moov);
      expect(back.volumeBytes, p.volumeBytes);
      expect(back.start, p.start);
      expect(back.end, p.end);
      expect(back.thresholds, {80});
      expect(back.recurring, isTrue);
    });

    test('la mesure s’arrête à la fin du forfait', () {
      final p = plan();
      expect(p.measuredUntil(DateTime(2026, 10, 19)), DateTime(2026, 10, 19));
      expect(p.measuredUntil(DateTime(2026, 11, 1)), p.end);
      expect(p.isExpired(p.end), isTrue);
    });

    test('nouveau suivi : même durée de validité', () {
      final restarted = plan().restartedAt(DateTime(2026, 10, 22, 9));
      expect(restarted.end, DateTime(2026, 10, 29, 9));
    });
  });

  group('saisie du volume', () {
    test('Go, Mo et virgule', () {
      expect(parseVolume('5', VolumeUnit.go), 5 * go);
      expect(parseVolume('1,5', VolumeUnit.go), (1.5 * go).round());
      expect(parseVolume('5 120', VolumeUnit.mo), 5120 * mo);
      expect(parseVolume('', VolumeUnit.go), isNull);
      expect(parseVolume('0', VolumeUnit.go), isNull);
    });

    test('conversion sans perte entre Mo et Go', () {
      expect(volumeText(5 * go, VolumeUnit.mo), '5120');
      expect(volumeText(5120 * mo, VolumeUnit.go), '5');
      expect(volumeText(500 * mo, VolumeUnit.go), '0,49');
    });
  });

  group('applications', () {
    test('regroupe les uids système et trie par volume', () {
      final rows = UsageSource.aggregate([
        const AppUsage(owner: UsageOwner.system, bytes: 10),
        const AppUsage(owner: UsageOwner.app, bytes: 50, packageName: 'a', label: 'A'),
        const AppUsage(owner: UsageOwner.system, bytes: 30),
        const AppUsage(owner: UsageOwner.app, bytes: 0, packageName: 'b', label: 'B'),
      ]);
      expect(rows.map((r) => r.displayName), ['A', 'Système Android']);
      expect(rows.last.bytes, 40);
    });

    test('tri par nom sans tenir compte des accents', () {
      final sorted = sortApps(const [
        AppUsage(owner: UsageOwner.app, bytes: 1, packageName: 'z', label: 'Zoom'),
        AppUsage(owner: UsageOwner.app, bytes: 2, packageName: 'e', label: 'Éducation'),
        AppUsage(owner: UsageOwner.app, bytes: 3, packageName: 'c', label: 'Chrome'),
      ], AppSort.name);
      expect(sorted.map((a) => a.displayName), ['Chrome', 'Éducation', 'Zoom']);
    });
  });

  group('conseils', () {
    test('la vidéo passe en premier au-delà d’un quart des données', () {
      final focus = focusFor(const [
        AppUsage(owner: UsageOwner.app, bytes: 40, packageName: 'com.zhiliaoapp.musically', label: 'TikTok'),
        AppUsage(owner: UsageOwner.app, bytes: 35, packageName: 'com.whatsapp', label: 'WhatsApp'),
        AppUsage(owner: UsageOwner.app, bytes: 25, packageName: 'x', label: 'X', category: 'video'),
      ])!;
      expect(focus.category, TipCategory.video);
      expect(focus.share, closeTo(0.65, 0.001));
    });

    test('sinon, l’application la plus gourmande', () {
      final focus = focusFor(const [
        AppUsage(owner: UsageOwner.app, bytes: 70, packageName: 'com.whatsapp', label: 'WhatsApp'),
        AppUsage(owner: UsageOwner.app, bytes: 30, packageName: 'com.android.chrome', label: 'Chrome'),
      ])!;
      expect(focus.category, isNull);
      expect(focus.headline, startsWith('WhatsApp'));
    });

    test('rien à dire sans consommation', () {
      expect(focusFor(const []), isNull);
    });
  });
}
