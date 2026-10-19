import 'package:datawatch/core/format.dart';
import 'package:datawatch/core/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sizeParts', () {
    test('Go avec deux décimales au plus sous 10 Go, sans zéros inutiles', () {
      expect(
        formatBytes((1.21 * DataUnits.bytesPerGo).round()),
        '1,21${nbsp}Go',
      );
      expect(formatBytes((1.5 * DataUnits.bytesPerGo).round()), '1,5${nbsp}Go');
      expect(formatBytes(5 * DataUnits.bytesPerGo), '5${nbsp}Go');
    });

    test('Go avec une décimale à partir de 10 Go', () {
      expect(
        formatBytes((11.4 * DataUnits.bytesPerGo).round()),
        '11,4${nbsp}Go',
      );
    });

    test('Mo entiers sous 1 Go', () {
      expect(formatBytes(901 * DataUnits.bytesPerMo), '901${nbsp}Mo');
    });

    test('pas de « 1024 Mo » : on bascule en Go', () {
      expect(formatBytes(DataUnits.bytesPerGo - 1000), '1${nbsp}Go');
    });

    test('petits volumes et valeurs négatives', () {
      expect(formatBytes(512), '512${nbsp}o');
      expect(formatBytes(3 * DataUnits.bytesPerKo), '3${nbsp}Ko');
      expect(formatBytes(-10), '0${nbsp}Mo');
      expect(formatBytes(0), '0${nbsp}Mo');
    });

    test('valeur et unité séparées pour le grand chiffre', () {
      final parts = sizeParts((1.38 * DataUnits.bytesPerGo).round());
      expect(parts.value, '1,38');
      expect(parts.unit, 'Go');
    });
  });

  test('formatShare', () {
    expect(formatShare(0.334), '33$nbsp%');
    expect(formatShare(0.004), '<${nbsp}1$nbsp%');
    expect(formatShare(0), '0$nbsp%');
  });

  test('formatNumber retire les zéros inutiles', () {
    expect(formatNumber(2.5), '2,5');
    expect(formatNumber(4), '4');
    expect(formatNumber(5120, maxDecimals: 0), '5120');
  });

  test('formatThousands', () {
    expect(formatThousands(5120), '5${nbsp}120');
    expect(formatThousands(999), '999');
    expect(formatThousands(1234567), '1${nbsp}234${nbsp}567');
  });

  test('dates à la française', () {
    final d = DateTime(2026, 10, 22, 8, 30);
    expect(formatDayMonthTime(d), '22 oct. à 08:30');
    expect(formatDate(DateTime(2026, 10, 1)), '1er oct. 2026');
    expect(formatLongDate(DateTime(2026, 10, 19)), 'lundi 19 octobre');
    expect(formatPartOfDay(DateTime(2026, 10, 21, 5, 17)), 'au matin');
    expect(formatPartOfDay(DateTime(2026, 10, 21, 23, 30)), 'dans la nuit');
  });

  test('formatRemaining', () {
    expect(
      formatRemaining(const Duration(days: 2, hours: 18, minutes: 5)),
      '2${nbsp}j 18${nbsp}h',
    );
    expect(
      formatRemaining(const Duration(hours: 5, minutes: 12)),
      '5${nbsp}h 12${nbsp}min',
    );
    expect(formatRemaining(const Duration(seconds: 20)), '1${nbsp}min');
    expect(formatRemaining(const Duration(minutes: -3)), '0${nbsp}min');
  });
}
