import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/format.dart';
import '../../data/usage_source.dart';
import '../period_text.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/page_header.dart';
import '../widgets/segmented.dart';
import '../widgets/usage_row.dart';

enum AppSort {
  desc('Plus gourmandes'),
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
    final apps = source == null ? null : sortApps(source, _sort);
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
    final barColor = _network == NetworkKind.mobile ? c.strong : c.wifi;
    final appCount = apps?.where((a) => a.owner == UsageOwner.app).length ?? 0;

    return DwPage(
      title: 'Applications',
      overline: 'Période · ${controller.effectivePeriod.label}',
      subtitle: snapshot == null
          ? null
          : Text(periodCaption(snapshot.period, snapshot.range)),
      actions: widget.actions,
      onRefresh: controller.refresh,
      children: [
        DwSegmented<NetworkKind>(
          values: NetworkKind.values,
          selected: _network,
          fontSize: 14,
          labelOf: (n) => n == NetworkKind.mobile ? 'Données mobiles' : 'Wi-Fi',
          iconOf: (n) => n == NetworkKind.mobile
              ? Icons.signal_cellular_alt_rounded
              : Icons.wifi_rounded,
          selectedColorOf: (n) => n == NetworkKind.mobile ? c.strong : c.wifi,
          onChanged: (n) => setState(() => _network = n),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    apps == null ? '…' : formatBytes(total),
                    style: DwFonts.style(
                      DwFonts.display,
                      36,
                      700,
                      height: 1,
                      letterSpacing: -1.4,
                      tabular: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'mesurés sur $appCount application${appCount > 1 ? 's' : ''}',
                    style: t.bodySmall!.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _sort = _sort.next),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 44),
                side: BorderSide(color: c.divider),
                backgroundColor: c.surface,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: t.titleSmall!.copyWith(fontSize: 13.5),
              ),
              icon: const Icon(Icons.swap_vert_rounded, size: 18),
              label: Text(_sort.label),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DwCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: apps == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : apps.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    _network == NetworkKind.mobile
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
                        barColor: barColor,
                        iconSize: 44,
                        height: 68,
                        showDivider: i > 0,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Android regroupe le système et les applications désinstallées. Les applications sans icône dans le lanceur apparaissent sous « Autres services ».',
                style: t.bodySmall!.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tri de la liste ; le tri par nom ignore les accents.
List<AppUsage> sortApps(List<AppUsage> apps, AppSort sort) {
  final sorted = [...apps];
  switch (sort) {
    case AppSort.desc:
      sorted.sort((a, b) => b.bytes.compareTo(a.bytes));
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
