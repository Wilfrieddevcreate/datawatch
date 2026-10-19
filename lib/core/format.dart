import 'units.dart';

/// Espace insécable : en français, « 5 Go » et « 80 % » ne se coupent pas.
const String nbsp = ' ';

/// Un volume prêt à afficher, séparé en valeur et unité pour la mise en page.
class SizeParts {
  const SizeParts(this.value, this.unit);

  final String value;
  final String unit;

  @override
  String toString() => '$value$nbsp$unit';
}

/// Formate un volume en restant lisible : 2 décimales sous 10 Go, 1 au-delà,
/// Mo entiers sous 1 Go.
SizeParts sizeParts(int bytes) {
  final b = bytes < 0 ? 0 : bytes;
  final go = b / DataUnits.bytesPerGo;
  if (go >= 10) return SizeParts(_decimal(go, 1), 'Go');
  if (go >= 1) return SizeParts(_decimal(go, 2), 'Go');

  final mo = b / DataUnits.bytesPerMo;
  if (mo >= 1) {
    final rounded = mo.round();
    return rounded >= DataUnits.base
        ? SizeParts(_decimal(1, 2), 'Go')
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

String formatBytes(int bytes) => sizeParts(bytes).toString();

/// « 33 % », ou « < 1 % » pour une part non nulle mais minuscule.
String formatShare(double fraction) {
  if (fraction > 0 && fraction < 0.01) return '<${nbsp}1$nbsp%';
  return '${(fraction * 100).round()}$nbsp%';
}

/// Nombre décimal à la française, sans zéros inutiles : 2,5 · 4 · 0,75.
String formatNumber(num value, {int maxDecimals = 2}) {
  var text = value.toStringAsFixed(maxDecimals);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return text.replaceAll('.', ',');
}

/// Entier avec séparateur de milliers : 5 120.
String formatThousands(int value) => value
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => nbsp);

String _decimal(double value, int digits) =>
    value.toStringAsFixed(digits).replaceAll('.', ',');

const List<String> _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// « 22 », ou « 1er » pour le premier du mois.
String formatDayNumber(DateTime d) => d.day == 1 ? '1er' : '${d.day}';

/// « 22 oct. »
String formatDayMonth(DateTime d) => '${formatDayNumber(d)} ${_months[d.month - 1]}';

/// « 22 oct. 2026 »
String formatDate(DateTime d) => '${formatDayMonth(d)} ${d.year}';

/// « 08:30 »
String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// « 22 oct. à 08:30 »
String formatDayMonthTime(DateTime d) => '${formatDayMonth(d)} à ${formatTime(d)}';

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
