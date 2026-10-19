import '../app/app_controller.dart';
import '../core/format.dart';

/// Phrase qui décrit la fenêtre de mesure affichée.
String periodCaption(UsagePeriod period, DateRange range) {
  final start = range.start;
  final end = range.end;
  return switch (period) {
    UsagePeriod.today => 'Aujourd’hui, depuis minuit',
    UsagePeriod.week => start.month == end.month
        ? 'Du ${formatDayNumber(start)} au ${formatDayMonth(end)}'
        : 'Du ${formatDayMonth(start)} au ${formatDayMonth(end)}',
    UsagePeriod.month => 'Depuis le ${formatDayMonth(start)}',
    UsagePeriod.plan => 'Depuis le début du forfait, le ${formatDayMonthTime(start)}',
  };
}
