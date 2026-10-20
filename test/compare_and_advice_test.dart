import 'package:datawatch/app/app_controller.dart';
import 'package:datawatch/core/format.dart';
import 'package:datawatch/core/units.dart';
import 'package:datawatch/data/usage_source.dart';
import 'package:datawatch/domain/tips.dart';
import 'package:flutter_test/flutter_test.dart';

const mo = DataUnits.bytesPerMo;
const go = DataUnits.bytesPerGo;

AppUsage app(
  String pkg, {
  String? label,
  String? category,
  int bytes = 100 * mo,
}) => AppUsage(
  owner: UsageOwner.app,
  bytes: bytes,
  packageName: pkg,
  label: label ?? pkg,
  category: category,
);

void main() {
  group('période précédente comparable', () {
    test('aujourd’hui → la veille, mêmes heures', () {
      final r = DateRange(
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 19, 14, 26),
      );
      final p = previousRangeFor(UsagePeriod.today, r)!;
      expect(p.start, DateTime(2026, 10, 18));
      expect(p.end, DateTime(2026, 10, 18, 14, 26));
    });

    test('7 jours → les 7 jours d’avant', () {
      final r = DateRange(
        DateTime(2026, 10, 13),
        DateTime(2026, 10, 19, 14, 26),
      );
      final p = previousRangeFor(UsagePeriod.week, r)!;
      expect(p.start, DateTime(2026, 10, 6));
      expect(p.end, DateTime(2026, 10, 12, 14, 26));
    });

    test('mois → mêmes jours du mois précédent, sans déborder', () {
      final r = DateRange(DateTime(2026, 3), DateTime(2026, 3, 31, 20));
      final p = previousRangeFor(UsagePeriod.month, r)!;
      expect(p.start, DateTime(2026, 2));
      expect(p.end, DateTime(2026, 2, 28, 20));
    });

    test('forfait → même durée avant son début', () {
      final r = DateRange(
        DateTime(2026, 10, 15, 8, 30),
        DateTime(2026, 10, 19, 8, 30),
      );
      final p = previousRangeFor(UsagePeriod.plan, r)!;
      expect(p.start, DateTime(2026, 10, 11, 8, 30));
      expect(p.end, r.start);
    });

    test('période vide : pas de comparaison', () {
      final t = DateTime(2026, 10, 19);
      expect(previousRangeFor(UsagePeriod.plan, DateRange(t, t)), isNull);
    });
  });

  group('évolution', () {
    test('hausse et baisse', () {
      expect(variation(118 * mo, 100 * mo), closeTo(0.18, 1e-9));
      expect(variation(88 * mo, 100 * mo), closeTo(-0.12, 1e-9));
    });

    test('référence trop faible ou absente : rien à afficher', () {
      expect(variation(50 * mo, null), isNull);
      expect(variation(50 * mo, mo ~/ 2), isNull);
    });

    test('libellés', () {
      expect(formatVariation(0.18), '↑${nbsp}18$nbsp%');
      expect(formatVariation(-0.124), '↓${nbsp}12$nbsp%');
      expect(formatVariation(0.001), '=${nbsp}0$nbsp%');
      expect(formatVariation(40), '↑${nbsp}999$nbsp%');
      expect(variationSentence(0.18), contains('en hausse de 18 %'));
    });
  });

  group('unités d’affichage', () {
    tearDown(() => displayUnits = UnitMode.auto);

    test('toujours en Mo', () {
      expect(
        formatBytes(3707 * mo, units: UnitMode.mo),
        '3${nbsp}707${nbsp}Mo',
      );
      expect(formatBytes(mo * 3 ~/ 2, units: UnitMode.mo), '1,5${nbsp}Mo');
    });

    test('toujours en Go', () {
      expect(formatBytes(533 * mo, units: UnitMode.go), '0,52${nbsp}Go');
      expect(formatBytes(mo, units: UnitMode.go), '<${nbsp}0,01${nbsp}Go');
    });

    test('le réglage global s’applique partout', () {
      displayUnits = UnitMode.mo;
      expect(formatBytes(2 * go), '2${nbsp}048${nbsp}Mo');
    });
  });

  group('conseils par application', () {
    test('familles reconnues', () {
      expect(appKindOf(app('com.zhiliaoapp.musically')), AppKind.video);
      expect(appKindOf(app('com.whatsapp')), AppKind.messaging);
      expect(appKindOf(app('com.facebook.katana')), AppKind.social);
      expect(appKindOf(app('com.transsion.phoenix')), AppKind.browser);
      expect(appKindOf(app('com.afmobi.boomplayer')), AppKind.audio);
      expect(appKindOf(app('x.y', category: 'video')), AppKind.video);
      expect(appKindOf(app('x.y')), AppKind.other);
    });

    test('trois conseils au plus, dont toujours l’arrière-plan', () {
      final tips = adviceFor(app('com.whatsapp', label: 'WhatsApp'));
      expect(tips, hasLength(3));
      expect(tips.first.title, 'Médias en Wi-Fi uniquement');
      expect(tips.first.body, contains('WhatsApp'));
      expect(tips.last.icon, AdviceIcon.background);
    });

    test('application surtout utilisée en Wi-Fi', () {
      final tips = adviceFor(
        app('com.zhiliaoapp.musically', label: 'TikTok'),
        wifiBytes: 400 * mo,
      );
      expect(tips.map((t) => t.icon), [
        AdviceIcon.video,
        AdviceIcon.wifi,
        AdviceIcon.background,
      ]);
    });

    test('application inconnue : le réglage Android suffit', () {
      expect(adviceFor(app('x.y')).map((t) => t.icon), [AdviceIcon.background]);
    });
  });
}
