import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/usage_source.dart';
import '../../domain/tips.dart';
import '../period_text.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/page_header.dart';
import '../widgets/usage_row.dart';

/// Détail d'une application (cahier des charges, section 5.3).
class AppDetailScreen extends StatefulWidget {
  const AppDetailScreen({super.key, required this.app});

  /// L'application touchée dans une liste (mobile ou Wi-Fi).
  final AppUsage app;

  static Route<void> route(AppUsage app) =>
      MaterialPageRoute(builder: (_) => AppDetailScreen(app: app));

  @override
  State<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends State<AppDetailScreen> {
  Future<List<int>>? _week;
  late List<DateTime> _days;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_week != null) return;
    final controller = AppScope.of(context);
    final now = controller.now();
    final today = DateTime(now.year, now.month, now.day);
    _days = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    final uid = widget.app.uid;
    if (uid == null) {
      _week = Future.value(const []);
      return;
    }
    final ranges = [
      for (final day in _days)
        (
          start: day.millisecondsSinceEpoch,
          end: math.min(
            DateTime(day.year, day.month, day.day + 1).millisecondsSinceEpoch,
            now.millisecondsSinceEpoch,
          ),
        ),
    ];
    _week = controller.source.appUsageByRange(uid, NetworkKind.mobile, ranges);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final snapshot = controller.snapshot;
    final app = widget.app;
    final name = app.displayName;

    AppUsage? find(List<AppUsage>? list) {
      for (final a in list ?? const <AppUsage>[]) {
        if (a.key == app.key) return a;
      }
      return null;
    }

    final mobile = find(snapshot?.mobileApps);
    final wifi = find(snapshot?.wifiApps);
    final mobileBytes = mobile?.bytes ?? 0;
    final total = snapshot?.totalFor(NetworkKind.mobile) ?? 0;
    final share = total == 0 ? 0.0 : mobileBytes / total;
    final isTop =
        mobile != null &&
        snapshot!.mobileApps.isNotEmpty &&
        snapshot.mobileApps.first.key == app.key;
    final change = mobile == null
        ? null
        : snapshot!.variationOf(mobile, NetworkKind.mobile);
    final advice = adviceFor(mobile ?? app, wifiBytes: wifi?.bytes);
    final screenTime = snapshot?.screenTimeOf(app);
    final perHour = snapshot?.perHourOf(app);
    final plan = controller.plan;

    return Scaffold(
      body: DwPage(
        leading: const DwBackButton(),
        titleLeading: UsageOwnerIcon(
          usage: app,
          source: controller.source,
          size: 52,
        ),
        title: name,
        overline: 'Période · ${controller.effectivePeriod.label}',
        subtitle: snapshot == null
            ? null
            : Text(periodCaption(snapshot.period, snapshot.range)),
        children: [
          _Hero(
            mobileBytes: mobileBytes,
            wifiBytes: wifi?.bytes ?? 0,
            share: share,
            isTop: isTop,
            change: change,
            screenTime: screenTime,
          ),
          const SizedBox(height: 12),
          if (perHour != null) ...[
            _HourCost(
              name: name,
              perHour: perHour,
              planVolume: plan?.volumeBytes,
            ),
            const SizedBox(height: 12),
          ],
          if (app.uid != null) ...[
            FutureBuilder<List<int>>(
              future: _week,
              builder: (context, snap) => _WeekChart(
                days: _days,
                values: snap.hasData ? snap.data : null,
                failed: snap.hasError,
              ),
            ),
            const SizedBox(height: 28),
          ],
          Text('Conseils pour $name', style: t.titleLarge),
          const SizedBox(height: 12),
          DwCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Column(
              children: [
                for (final (i, a) in advice.indexed)
                  _AdviceRow(advice: a, divider: i > 0),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (app.packageName != null)
            OutlinedButton.icon(
              onPressed: () => controller.openAppSettings(app.packageName!),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                'Ouvrir les réglages Android de $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'DataWatch ne modifie jamais les réglages d’une autre application.',
            textAlign: TextAlign.center,
            style: t.bodySmall!.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.mobileBytes,
    required this.wifiBytes,
    required this.share,
    required this.isTop,
    required this.change,
    required this.screenTime,
  });

  final int mobileBytes;
  final int wifiBytes;
  final double share;
  final bool isTop;
  final double? change;

  /// Temps d'écran de la période, s'il est connu.
  final Duration? screenTime;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final parts = sizeParts(mobileBytes);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.hero,
        borderRadius: BorderRadius.circular(DwRadius.xl),
        border: Border.all(color: c.heroBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'DONNÉES MOBILES',
                  style: DwFonts.overline(c.heroTextSecondary),
                ),
              ),
              if (change != null)
                Semantics(
                  label: variationSentence(change!),
                  excludeSemantics: true,
                  child: _DarkVariation(change: change!),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    parts.value,
                    style: DwFonts.hero(60).copyWith(color: c.heroText),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                parts.unit,
                style: DwFonts.style(
                  DwFonts.display,
                  22,
                  600,
                ).copyWith(color: c.heroText),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            label: '${formatShare(share)} de la consommation mobile',
            excludeSemantics: true,
            child: Row(
              children: [
                Expanded(
                  flex: math.max(1, (share * 1000).round()),
                  child: Container(
                    height: 10,
                    decoration: const BoxDecoration(
                      color: DwColors.tankOk,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: math.max(1, ((1 - share) * 1000).round()),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.tankBorder,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatShare(share),
                  style: TextStyle(color: c.heroText).weight(600),
                ),
                TextSpan(
                  text: isTop
                      ? ' de vos données mobiles : c’est votre application la plus gourmande.'
                      : ' de vos données mobiles sur la période.',
                ),
              ],
            ),
            style: t.bodyMedium!.copyWith(color: const Color(0xFFC9CFD9)),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: const Color(0x1AFFFFFF)),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.wifi_rounded,
                size: 17,
                color: const Color(0xFF8DA2FF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Wi-Fi · hors forfait',
                  style: t.bodyMedium!.copyWith(color: const Color(0xFFC9CFD9)),
                ),
              ),
              Text(
                formatBytes(wifiBytes),
                style: t.titleSmall!.copyWith(color: c.heroText),
              ),
            ],
          ),
          if (screenTime != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.hourglass_bottom_rounded,
                  size: 17,
                  color: DwColors.tankOk,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Temps d’écran',
                    style: t.bodyMedium!.copyWith(
                      color: const Color(0xFFC9CFD9),
                    ),
                  ),
                ),
                Text(
                  formatScreenTime(screenTime!),
                  style: t.titleSmall!.copyWith(color: c.heroText),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DarkVariation extends StatelessWidget {
  const _DarkVariation({required this.change});
  final double change;

  @override
  Widget build(BuildContext context) {
    final up = change > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: up ? const Color(0x29FF9F5A) : const Color(0x24C6F135),
        borderRadius: BorderRadius.circular(DwRadius.pill),
      ),
      child: Text(
        '${formatVariation(change)} vs avant',
        style: DwFonts.style(
          DwFonts.body,
          12.5,
          600,
        ).copyWith(color: up ? const Color(0xFFFFB27A) : DwColors.tankOk),
      ),
    );
  }
}

/// Barres des 7 derniers jours (une seule série : pas de légende de couleur).
/// Toucher une barre affiche sa valeur ; la plus haute est annotée par défaut.
class _WeekChart extends StatefulWidget {
  const _WeekChart({
    required this.days,
    required this.values,
    required this.failed,
  });

  final List<DateTime> days;
  final List<int>? values;
  final bool failed;

  @override
  State<_WeekChart> createState() => _WeekChartState();
}

class _WeekChartState extends State<_WeekChart> {
  static const _weekdays = ['lu', 'ma', 'me', 'je', 've', 'sa', 'di'];
  static const _plotHeight = 140.0;
  static const _labelHeight = 34.0;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final values = widget.values;

    Widget body;
    if (widget.failed) {
      body = SizedBox(
        height: _plotHeight,
        child: Center(
          child: Text(
            'Historique indisponible sur ce téléphone.',
            style: t.bodyMedium!.copyWith(color: c.textSecondary),
          ),
        ),
      );
    } else {
      final data = values ?? List<int>.filled(widget.days.length, 0);
      final maxValue = data.fold<int>(0, math.max);
      // Graduation ronde et échelle au palier juste au-dessus du maximum.
      final step = _niceStep(maxValue / 3);
      final lines = math.max(1, (maxValue / step).ceil());
      final scaleMax = step * lines;
      final selected =
          _selected ?? (maxValue > 0 ? data.indexOf(maxValue) : null);

      body = SizedBox(
        height: _plotHeight + _labelHeight + 28,
        child: Stack(
          children: [
            for (var k = 1; k <= lines; k++)
              Positioned(
                left: 0,
                right: 0,
                bottom: _labelHeight + _plotHeight * k / lines - 7,
                child: Row(
                  children: [
                    SizedBox(
                      width: 46,
                      child: Text(
                        formatBytes((step * k).round()),
                        style: DwFonts.style(
                          DwFonts.mono,
                          10.5,
                          400,
                        ).copyWith(color: c.textSecondary),
                      ),
                    ),
                    Expanded(child: Container(height: 1, color: c.divider)),
                  ],
                ),
              ),
            Positioned(
              left: 46,
              right: 0,
              bottom: _labelHeight,
              child: Container(height: 1, color: c.track),
            ),
            Positioned.fill(
              left: 46,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < data.length; i++)
                    Expanded(
                      child: _Bar(
                        label: i == data.length - 1
                            ? 'Auj.'
                            : '${_weekdays[widget.days[i].weekday - 1]}\n${widget.days[i].day}',
                        semanticLabel:
                            '${i == data.length - 1 ? 'Aujourd’hui' : formatLongDate(widget.days[i])} : ${formatBytes(data[i])}',
                        height: values == null || scaleMax == 0
                            ? 0
                            : _plotHeight * data[i] / scaleMax,
                        value: formatBytes(data[i]),
                        selected: values != null && i == selected,
                        partial: i == data.length - 1,
                        loading: values == null,
                        labelHeight: _labelHeight,
                        onTap: () => setState(() => _selected = i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return DwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Données mobiles, 7 jours', style: t.titleMedium),
              ),
              if (values == null && !widget.failed)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          body,
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: c.strong.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Aujourd’hui : journée en cours',
                style: t.bodySmall!.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Pas de graduation « rond » (1, 2 ou 5 × 10ⁿ Mo) pour les axes.
  static double _niceStep(double bytes) {
    if (bytes <= 0) return DataUnits.bytesPerMo.toDouble();
    final mo = bytes / DataUnits.bytesPerMo;
    final magnitude = math
        .pow(10, (math.log(mo) / math.ln10).floor())
        .toDouble();
    final f = mo / magnitude;
    final nice = f <= 1
        ? 1
        : f <= 2
        ? 2
        : f <= 5
        ? 5
        : 10;
    return nice * magnitude * DataUnits.bytesPerMo;
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.semanticLabel,
    required this.height,
    required this.value,
    required this.selected,
    required this.partial,
    required this.loading,
    required this.labelHeight,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final double height;
  final String value;
  final bool selected;
  final bool partial;
  final bool loading;
  final double labelHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (selected)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: c.strong,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: DwFonts.style(
                      DwFonts.body,
                      11.5,
                      600,
                    ).copyWith(color: c.onStrong),
                  ),
                ),
              ),
            Container(
              width: 20,
              height: loading ? 8 : math.max(height, 2),
              decoration: BoxDecoration(
                color: loading
                    ? c.track
                    : partial
                    ? c.strong.withValues(alpha: 0.35)
                    : c.strong,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
            SizedBox(
              height: labelHeight,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: DwFonts.style(
                    DwFonts.body,
                    11,
                    selected ? 600 : 400,
                    height: 1.15,
                  ).copyWith(color: selected ? c.text : c.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdviceRow extends StatelessWidget {
  const _AdviceRow({required this.advice, required this.divider});

  final AppAdvice advice;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final (icon, bg, fg) = switch (advice.icon) {
      AdviceIcon.video => (
        Icons.play_circle_outline_rounded,
        c.warningSoft,
        c.warningText,
      ),
      AdviceIcon.audio => (
        Icons.headphones_rounded,
        c.warningSoft,
        c.warningText,
      ),
      AdviceIcon.download => (Icons.download_rounded, c.wifiSoft, c.wifi),
      AdviceIcon.message => (
        Icons.chat_bubble_outline_rounded,
        c.positiveSoft,
        c.positiveText,
      ),
      AdviceIcon.browser => (Icons.public_rounded, c.wifiSoft, c.wifi),
      AdviceIcon.wifi => (Icons.wifi_rounded, c.wifiSoft, c.wifi),
      AdviceIcon.background => (
        Icons.smartphone_rounded,
        c.track,
        c.textSecondary,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: c.divider)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(DwRadius.md),
            ),
            child: Icon(icon, size: 20, color: fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(advice.title, style: t.titleMedium),
                const SizedBox(height: 2),
                Text(
                  advice.body,
                  style: t.bodyMedium!.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ce que coûte une heure dans l'application : toutes ses données (mobile et
/// Wi-Fi) divisées par son temps d'écran sur la période.
class _HourCost extends StatelessWidget {
  const _HourCost({
    required this.name,
    required this.perHour,
    required this.planVolume,
  });

  final String name;
  final int perHour;
  final int? planVolume;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final parts = sizeParts(perHour);
    final share = planVolume == null || planVolume! <= 0
        ? null
        : perHour / planVolume!;
    return DwCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.positiveSoft,
              borderRadius: BorderRadius.circular(DwRadius.md),
            ),
            child: Icon(Icons.timer_outlined, size: 22, color: c.positiveText),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DwOverline('Une heure de $name'),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '≈$nbsp${parts.value}',
                        style: DwFonts.style(
                          DwFonts.display,
                          34,
                          700,
                          letterSpacing: -1,
                          tabular: true,
                        ),
                      ),
                      TextSpan(
                        text: '$nbsp${parts.unit}',
                        style: DwFonts.style(DwFonts.display, 18, 600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  share == null
                      ? 'Données consommées en moyenne par heure d’utilisation.'
                      : 'En données mobiles, une heure ≈ ${formatShare(share)} de votre forfait de ${formatBytes(planVolume!)}.',
                  style: t.bodyMedium!.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
