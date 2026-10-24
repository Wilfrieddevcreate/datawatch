import 'package:datawatch/app/app_controller.dart';
import 'package:datawatch/core/format.dart';
import 'package:datawatch/core/units.dart';
import 'package:datawatch/data/usage_source.dart';
import 'package:datawatch/domain/tips.dart';
import 'package:datawatch/ui/screens/apps_screen.dart';
import 'package:flutter_test/flutter_test.dart';

const mo = DataUnits.bytesPerMo;
const go = DataUnits.bytesPerGo;

AppUsage app(String pkg, int bytes) =>
    AppUsage(owner: UsageOwner.app, bytes: bytes, packageName: pkg, label: pkg);

void main() {
  group('coût par heure', () {
    test('volume divisé par le temps d’écran', () {
      expect(bytesPerHour(600 * mo, const Duration(hours: 2)), 300 * mo);
      expect(bytesPerHour(150 * mo, const Duration(minutes: 30)), 300 * mo);
    });

    test('rien sous 10 minutes ni sans données', () {
      expect(bytesPerHour(50 * mo, const Duration(minutes: 9)), isNull);
      expect(bytesPerHour(0, const Duration(hours: 3)), isNull);
      expect(bytesPerHour(50 * mo, const Duration(minutes: 10)), 300 * mo);
    });
  });

  test('formatScreenTime', () {
    expect(
      formatScreenTime(const Duration(seconds: 40)),
      '<${nbsp}1${nbsp}min',
    );
    expect(formatScreenTime(const Duration(minutes: 42)), '42${nbsp}min');
    expect(
      formatScreenTime(const Duration(hours: 4, minutes: 5)),
      '4${nbsp}h${nbsp}05',
    );
  });

  test('formatPerHour', () {
    expect(formatPerHour(300 * mo), '300${nbsp}Mo/h');
  });

  group('phrase des conseils', () {
    test('part du forfait quand il est connu', () {
      expect(
        hourCostLine('TikTok', 512 * mo, 5 * go),
        'Une heure de TikTok ≈ ${formatBytes(512 * mo)}, soit 10$nbsp% de votre forfait.',
      );
    });

    test('sans forfait, sans temps d’écran', () {
      expect(
        hourCostLine('TikTok', 512 * mo, null),
        'Une heure de TikTok ≈ ${formatBytes(512 * mo)} de données.',
      );
      expect(hourCostLine('TikTok', null, 5 * go), isNull);
    });
  });

  test('tri par coût par heure : rythmes connus d’abord', () {
    final rates = {'video': 900 * mo, 'chat': 40 * mo};
    final sorted = sortApps(
      [
        app('big', 2 * go),
        app('chat', 300 * mo),
        app('video', go),
        app('small', 5 * mo),
      ],
      AppSort.perHour,
      perHourOf: (a) => rates[a.packageName],
    );
    expect(sorted.map((a) => a.packageName), ['video', 'chat', 'big', 'small']);
  });
}
