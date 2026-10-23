import 'units.dart';

/// Espace insécable : en français, « 5 Go » et « 80 % » ne se coupent pas.
const String nbsp = '\u00A0';

/// Un volume prêt à afficher, séparé en valeur et unité pour la mise en page.
class SizeParts {
  const SizeParts(this.value, this.unit);

  final String value;
  final String unit;

  @override
  String toString() => '$value$nbsp$unit';
}

/// Unités d'affichage choisies dans les paramètres.
enum UnitMode {
  /// Mo sous 1 Go, Go au-delà.
  auto('Auto'),
  mo('Mo'),
  go('Go');

  const UnitMode(this.label);
  final String label;
}

/// Unités utilisées par [sizeParts]. Réglées par le contrôleur au chargement
/// des paramètres ; les écrans se reconstruisent quand elles changent.
UnitMode displayUnits = UnitMode.auto;

/// Formate un volume en restant lisible : jusqu'à 2 décimales sous 10 Go,
/// 1 au-delà, Mo entiers sous 1 Go. Les zéros inutiles disparaissent (5 Go).
SizeParts sizeParts(int bytes, {UnitMode? units}) {
  final b = bytes < 0 ? 0 : bytes;
  if (b == 0) return const SizeParts('0', 'Mo');
  switch (units ?? displayUnits) {
    case UnitMode.mo:
      final mo = b / DataUnits.bytesPerMo;
      return mo < 10
          ? SizeParts(formatNumber(mo, maxDecimals: 1), 'Mo')
          : SizeParts(formatThousands(mo.round()), 'Mo');
    case UnitMode.go:
      final go = b / DataUnits.bytesPerGo;
      return go < 0.01
          ? const SizeParts('<\u00A00,01', 'Go')
          : SizeParts(formatNumber(go), 'Go');
    case UnitMode.auto:
      break;
  }
  final go = b / DataUnits.bytesPerGo;
  if (go >= 10) return SizeParts(formatNumber(go, maxDecimals: 1), 'Go');
  if (go >= 1) return SizeParts(formatNumber(go), 'Go');

  final mo = b / DataUnits.bytesPerMo;
  if (mo >= 1) {
    final rounded = mo.round();
    return rounded >= DataUnits.base
        ? const SizeParts('1', 'Go')
        : SizeParts('$rounded', 'Mo');
  }

  final ko = b / DataUnits.bytesPerKo;
  if (ko >= 1) {
    final rounded = ko.round();
    return rounded >= DataUnits.base
        ? const SizeParts('1', 'Mo')
        : SizeParts('$rounded', 'Ko');
  }
  return SizeParts('$b', 'o');
}

String formatBytes(int bytes, {UnitMode? units}) =>
    sizeParts(bytes, units: units).toString();

/// Temps d'écran : « 4 h 40 », « 45 min », « < 1 min ».
String formatScreenTime(Duration d) {
  if (d.inMinutes < 1) return '<${nbsp}1${nbsp}min';
  if (d.inHours == 0) return '${d.inMinutes}${nbsp}min';
  final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
  return '${d.inHours}${nbsp}h$nbsp$minutes';
}

/// Débit par heure d'utilisation : « 1,05 Go/h », « 590 Mo/h ».
String formatPerHour(int bytesPerHour) => '${formatBytes(bytesPerHour)}/h';

/// « 33 % », ou « < 1 % » pour une part non nulle mais minuscule.
String formatShare(double fraction) {
  if (fraction > 0 && fraction < 0.01) return '<${nbsp}1$nbsp%';
  return '${(fraction * 100).round()}$nbsp%';
}

/// « ↑ 18 % », « ↓ 12 % », « = » sous 1 %. Plafonné à 999 %.
String formatVariation(double v) {
  final pct = (v.abs() * 100).round().clamp(0, 999);
  if (pct == 0) return '=${nbsp}0$nbsp%';
  return '${v > 0 ? '↑' : '↓'}$nbsp$pct$nbsp%';
}

/// Version lue par les lecteurs d'écran.
String variationSentence(double v) {
  final pct = (v.abs() * 100).round().clamp(0, 999);
  if (pct == 0) return 'stable par rapport à la période précédente';
  return '${v > 0 ? 'en hausse' : 'en baisse'} de $pct % par rapport à la période précédente';
}

/// Nombre décimal à la française, sans zéros inutiles : 2,5 · 4 · 0,75.
String formatNumber(num value, {int maxDecimals = 2}) {
  var text = value.toStringAsFixed(maxDecimals);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return text.replaceAll('.', ',');
}

/// Entier avec séparateur de milliers : 5 120.
String formatThousands(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => nbsp,
);

const List<String> _months = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

const List<String> _monthsLong = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

const List<String> _weekdays = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

/// « lundi 19 octobre »
String formatLongDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${formatDayNumber(d)} ${_monthsLong[d.month - 1]}';

String _two(int n) => n.toString().padLeft(2, '0');

/// « 22 », ou « 1er » pour le premier du mois.
String formatDayNumber(DateTime d) => d.day == 1 ? '1er' : '${d.day}';

/// « 22 oct. »
String formatDayMonth(DateTime d) =>
    '${formatDayNumber(d)} ${_months[d.month - 1]}';

/// « 22 oct. 2026 »
String formatDate(DateTime d) => '${formatDayMonth(d)} ${d.year}';

/// « 08:30 »
String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// Moment de la journée, pour une projection qui n'a pas de sens à la minute
/// près : « au matin », « dans l'après-midi »…
String formatPartOfDay(DateTime d) => switch (d.hour) {
  >= 5 && < 12 => 'au matin',
  >= 12 && < 18 => 'dans l’après-midi',
  >= 18 && < 23 => 'dans la soirée',
  _ => 'dans la nuit',
};

/// « 22 oct. à 08:30 »
String formatDayMonthTime(DateTime d) =>
    '${formatDayMonth(d)} à ${formatTime(d)}';

/// Durée courte pour un compte à rebours : « 2 j 18 h », « 5 h 12 min », « 12 min ».
String formatRemaining(Duration d) {
  if (d.isNegative || d == Duration.zero) return '0${nbsp}min';
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  if (days > 0) return '$days${nbsp}j $hours${nbsp}h';
  if (d.inHours > 0) return '${d.inHours}${nbsp}h $minutes${nbsp}min';
  return '${d.inMinutes < 1 ? 1 : d.inMinutes}${nbsp}min';
}
