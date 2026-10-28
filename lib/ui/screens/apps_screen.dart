import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/format.dart';
import '../../data/usage_source.dart';
import '../period_text.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/page_header.dart';
import '../widgets/primitives.dart';
import '../widgets/text_tabs.dart';
import '../widgets/usage_row.dart';
import 'app_detail_screen.dart';

enum AppSort {
  desc('Plus gourmandes'),
  perHour('Coût par heure'),
  asc('Moins gourmandes'),
  name('Nom (A–Z)');

  const AppSort(this.label);
  final String label;

  AppSort get next => AppSort.values[(index + 1) % AppSort.values.length];
}

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key, required this.actions});

  final List<Widget> actions;

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  NetworkKind _network = NetworkKind.mobile;
  AppSort _sort = AppSort.desc;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final snapshot = controller.snapshot;
    final source = _network == NetworkKind.mobile
        ? snapshot?.mobileApps
        : snapshot?.wifiApps;
    final apps = source == null
        ? null
        : sortApps(source, _sort, perHourOf: snapshot?.perHourOf);
    // Même total que l'accueil (compteur de l'appareil) ; la somme des
    // applications ne sert que si Android ne le fournit pas.
    final appsSum = apps?.fold<int>(0, (sum, a) => sum + a.bytes) ?? 0;
    final deviceTotal = _network == NetworkKind.mobile
        ? snapshot?.totals.mobileBytes
        : snapshot?.totals.wifiBytes;
    final total = deviceTotal != null && deviceTotal >= appsSum
        ? deviceTotal
        : appsSum;
    final max = apps == null || apps.isEmpty
        ? 1
        : apps.map((a) => a.bytes).reduce((a, b) => a > b ? a : b);
    final mobile = _network == NetworkKind.mobile;
    final accent = mobile ? c.accent : c.wifi;
    final appCount = apps?.where((a) => a.owner == UsageOwner.app).length ?? 0;
    final totalParts = apps == null ? null : sizeParts(total);
    final totalSplit = totalParts?.value.split(',');

    return DwPage(
      title: 'Applications',
      subtitle: snapshot == null
          ? null
          : Text(periodCaption(snapshot.period, snapshot.range)),
      actions: widget.actions,
      onRefresh: controller.refresh,
      children: [
        DwTextTabs<NetworkKind>(
          values: NetworkKind.values,
          selected: _network,
          fontSize: 14,
          underlineColor: accent,
          labelOf: (n) => n == NetworkKind.mobile ? 'Données mobiles' : 'Wi-Fi',
          onChanged: (n) => setState(() => _network = n),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (totalParts == null || totalSplit == null)
                    Text('…', style: DwFonts.hero(48))
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: totalSplit[0],
                              style: DwFonts.hero(48),
                            ),
                            if (totalSplit.length > 1) ...[
                              TextSpan(
                                text: ',',
                                style: DwFonts.hero(
                                  48,
                                ).copyWith(color: accent),
                              ),
                              TextSpan(
                                text: totalSplit[1],
                                style: DwFonts.hero(48),
                              ),
                            ],
                            TextSpan(
                              text: '$nbsp${totalParts.unit}',
                              style: DwFonts.style(
                                DwFonts.display,
                                22,
                                500,
                              ).copyWith(color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'mesurés sur $appCount application${appCount > 1 ? 's' : ''}',
                    style: t.bodySmall!.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                var next = _sort.next;
                // Sans temps d'écran, le coût par heure n'a pas de sens.
                if (next == AppSort.perHour && snapshot?.screenTime == null) {
                  next = next.next;
                }
                _sort = next;
              }),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: t.titleSmall!.copyWith(fontSize: 13.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_sort.label),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DwSheet(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
          child: apps == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: DwLoader()),
                )
              : apps.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    mobile
                        ? 'Aucune consommation mobile mesurée sur cette période.'
                        : 'Aucune consommation Wi-Fi mesurée sur cette période.',
                    style: t.bodyMedium!.copyWith(color: c.textSecondary),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < apps.length; i++)
                      UsageRow(
                        usage: apps[i],
                        source: controller.source,
                        share: total == 0 ? 0 : apps[i].bytes / total,
                        barFraction: apps[i].bytes / max,
                        barColor: mobile ? c.strong : c.wifi,
                        iconSize: 42,
                        height: 68,
                        showDivider: i > 0,
                        variation: snapshot?.variationOf(apps[i], _network),
                        secondaryLabel: _sort == AppSort.perHour
                            ? _perHourLabel(snapshot?.perHourOf(apps[i]))
                            : null,
                        onTap: apps[i].owner == UsageOwner.app
                            ? () => Navigator.of(
                                context,
                              ).push(AppDetailScreen.route(apps[i]))
                            : null,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Android regroupe le système et les applications désinstallées. Les applications sans icône dans le lanceur apparaissent sous « Autres services ».',
            style: t.bodySmall!.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}

String _perHourLabel(int? perHour) =>
    perHour == null ? '—' : formatPerHour(perHour);

/// Tri de la liste ; le tri par nom ignore les accents. Le coût par heure
/// place d'abord les applications dont on connaît le rythme, de la plus
/// coûteuse à la moins coûteuse, puis les autres par volume.
List<AppUsage> sortApps(
  List<AppUsage> apps,
  AppSort sort, {
  int? Function(AppUsage)? perHourOf,
}) {
  final sorted = [...apps];
  switch (sort) {
    case AppSort.desc:
      sorted.sort((a, b) => b.bytes.compareTo(a.bytes));
    case AppSort.perHour:
      int? rate(AppUsage a) => perHourOf?.call(a);
      sorted.sort((a, b) {
        final ra = rate(a), rb = rate(b);
        if (ra != null && rb != null) return rb.compareTo(ra);
        if (ra != null) return -1;
        if (rb != null) return 1;
        return b.bytes.compareTo(a.bytes);
      });
    case AppSort.asc:
      sorted.sort((a, b) => a.bytes.compareTo(b.bytes));
    case AppSort.name:
      sorted.sort(
        (a, b) => _fold(a.displayName).compareTo(_fold(b.displayName)),
      );
  }
  return sorted;
}

String _fold(String s) {
  const from = 'àâäáãéèêëíìîïóòôöõúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final lower = s.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    buffer.write(i < 0 ? ch : to[i]);
  }
  return buffer.toString();
}
