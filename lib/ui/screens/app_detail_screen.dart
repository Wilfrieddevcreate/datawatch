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
import '../widgets/primitives.dart';
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
          size: 56,
        ),
        title: name,
        subtitle: snapshot == null
            ? null
            : Text(periodCaption(snapshot.period, snapshot.range)),
        children: [
          DwReveal(
            child: _Hero(
              mobileBytes: mobileBytes,
              wifiBytes: wifi?.bytes ?? 0,
              share: share,
              isTop: isTop,
              change: change,
              screenTime: screenTime,
              name: name,
              perHour: perHour,
              planVolume: plan?.volumeBytes,
            ),
          ),
          const SizedBox(height: 16),
          if (app.uid != null) ...[
            DwReveal(
              delay: 1,
              child: FutureBuilder<List<int>>(
                future: _week,
                builder: (context, snap) => _WeekChart(
                  days: _days,
                  values: snap.hasData ? snap.data : null,
                  failed: snap.hasError,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          DwReveal(
            delay: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DwSectionTitle('Conseils pour $name'),
                const SizedBox(height: 12),
                DwSheet(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                  child: Column(
                    children: [
                      for (final (i, a) in advice.indexed)
                        _AdviceRow(advice: a, divider: i > 0),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (app.packageName != null)
            OutlinedButton.icon(
              onPressed: () => controller.openAppSettings(app.packageName!),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.open_in_new, size: 18),
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
    required this.name,
    required this.perHour,
    required this.planVolume,
  });

  final int mobileBytes;
  final int wifiBytes;
  final double share;
  final bool isTop;
  final double? change;

  /// Temps d'écran de la période, s'il est connu.
  final Duration? screenTime;
  final String name;
  final int? perHour;
  final int? planVolume;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final parts = sizeParts(mobileBytes);
    final split = parts.value.split(',');
    const soft = Color(0xFFC9CFD9);
    final hourShare = perHour == null || planVolume == null || planVolume! <= 0
        ? null
        : perHour! / planVolume!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.hero,
        borderRadius: BorderRadius.circular(DwRadius.lg + 4),
        border: Border.all(color: c.heroBorder),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: c.heroText),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Données mobiles',
                    style: DwFonts.label(c.heroTextSecondary),
                  ),
                ),
                if (change != null)
                  Semantics(
                    label: variationSentence(change!),
                    excludeSemantics: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DwVariation(variation: change!, large: true, onDark: true),
                        Text(
                          ' vs précédent',
                          style: t.bodySmall!.copyWith(
                            color: c.heroTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: split[0], style: DwFonts.hero(72)),
                    if (split.length > 1) ...[
                      TextSpan(
                        text: ',',
                        style: DwFonts.hero(72).copyWith(color: c.accent),
                      ),
                      TextSpan(text: split[1], style: DwFonts.hero(72)),
                    ],
                    TextSpan(
                      text: '$nbsp${parts.unit}',
                      style: DwFonts.style(
                        DwFonts.display,
                        24,
                        500,
                      ).copyWith(color: soft),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              label: '${formatShare(share)} de la consommation mobile',
              excludeSemantics: true,
              child: DwBar(
                fraction: share,
                color: c.accent,
                track: c.tankBorder,
                height: 10,
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
                        ? ' de vos données mobiles : votre application la plus gourmande.'
                        : ' de vos données mobiles sur la période.',
                  ),
                ],
              ),
              style: t.bodyMedium!.copyWith(color: soft),
            ),
            const SizedBox(height: 8),
            _HeroRow(
              label: 'Wi-Fi · hors forfait',
              swatch: const Color(0xFF8DA2FF),
              value: formatBytes(wifiBytes),
            ),
            if (screenTime != null)
              _HeroRow(
                label: 'Temps d’écran',
                value: formatScreenTime(screenTime!),
              ),
            if (perHour != null) ...[
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.only(top: 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: DwDash(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Une heure de $name ≈ '),
                            TextSpan(
                              text: formatBytes(perHour!),
                              style: TextStyle(color: c.heroText).weight(600),
                            ),
                            if (hourShare != null) ...[
                              const TextSpan(text: ', soit '),
                              TextSpan(
                                text: formatShare(hourShare),
                                style: TextStyle(
                                  color: c.heroText,
                                ).weight(600),
                              ),
                              const TextSpan(text: ' de votre forfait.'),
                            ] else
                              const TextSpan(
                                text: ' en moyenne, mobile et Wi-Fi compris.',
                              ),
                          ],
                        ),
                        style: t.bodyMedium!.copyWith(color: soft),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroRow extends StatelessWidget {
  const _HeroRow({required this.label, required this.value, this.swatch});

  final String label;
  final String value;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Row(
        children: [
          if (swatch != null) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: swatch,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: t.bodyMedium!.copyWith(
                fontSize: 14,
                color: const Color(0xFFC9CFD9),
              ),
            ),
          ),
          Text(
            value,
            style: DwFonts.style(
              DwFonts.display,
              19,
              700,
              letterSpacing: -0.4,
              tabular: true,
            ).copyWith(color: c.heroText),
          ),
        ],
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
                          DwFonts.body,
                          10.5,
                          500,
                          tabular: true,
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

    return DwSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DwSectionTitle(
            '7 derniers jours',
            size: 20,
            trailing: values == null && !widget.failed
                ? const DwLoader(size: 18)
                : Text(
                    'données mobiles',
                    style: t.bodySmall!.copyWith(color: c.textSecondary),
                  ),
          ),
          const SizedBox(height: 8),
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
                  borderRadius: BorderRadius.circular(DwRadius.xs),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: DwFonts.style(
                      DwFonts.body,
                      11.5,
                      600,
                      tabular: true,
                    ).copyWith(color: c.onStrong),
                  ),
                ),
              ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: loading ? 8 : math.max(height, 2)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, h, _) => Container(
                width: 22,
                height: h,
                decoration: BoxDecoration(
                  color: loading
                      ? c.track
                      : partial
                      ? c.strong.withValues(alpha: 0.35)
                      : c.strong,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
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
    final icon = switch (advice.icon) {
      AdviceIcon.video => Icons.play_circle_outline,
      AdviceIcon.audio => Icons.headphones_outlined,
      AdviceIcon.download => Icons.download_outlined,
      AdviceIcon.message => Icons.chat_bubble_outline,
      AdviceIcon.browser => Icons.public,
      AdviceIcon.wifi => Icons.wifi,
      AdviceIcon.background => Icons.smartphone,
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: c.divider)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 22, color: c.text),
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
