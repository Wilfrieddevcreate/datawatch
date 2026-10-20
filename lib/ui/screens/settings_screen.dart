import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/format.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/page_header.dart';
import '../widgets/segmented.dart';
import '../widgets/usage_row.dart';
import 'info_screen.dart';

/// Paramètres (cahier des charges, section 5.7).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onOpenPlan});

  /// Ferme les paramètres et ouvre l'onglet Forfait.
  final VoidCallback onOpenPlan;

  static Route<void> route({required VoidCallback onOpenPlan}) =>
      MaterialPageRoute(builder: (_) => SettingsScreen(onOpenPlan: onOpenPlan));

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final settings = controller.settings;
    final device = controller.device;
    final plan = controller.plan;

    void openPlan() {
      Navigator.of(context).pop();
      onOpenPlan();
    }

    Future<void> allowNotifications() async {
      final granted = await controller.ensureNotificationPermission();
      if (!granted) await controller.openNotificationSettings();
    }

    Future<void> eraseAll() async {
      final messenger = ScaffoldMessenger.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Effacer les données locales ?'),
          content: const Text(
            'Votre forfait, vos seuils d’alerte, vos préférences et l’historique des alertes seront supprimés de ce téléphone. Les statistiques d’Android ne sont pas modifiées.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: context.dw.critical),
              child: const Text('Tout effacer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await controller.clearAllData();
      messenger.showSnackBar(
        const SnackBar(content: Text('Données locales effacées')),
      );
    }

    final thresholds = plan == null
        ? <int>[]
        : (plan.thresholds.toList()..sort());

    return Scaffold(
      body: DwPage(
        leading: const DwBackButton(),
        title: 'Paramètres',
        overline: 'DataWatch',
        subtitle: const Text(
          'Autorisations, alertes et données de l’application.',
        ),
        children: [
          _PrivacyCard(
            onOpen: () => Navigator.of(context).push(InfoScreen.privacy()),
          ),
          const SizedBox(height: 24),
          _Group(
            title: 'Autorisations',
            children: [
              _SettingRow(
                icon: Icons.signal_cellular_alt_rounded,
                title: 'Accès aux données d’utilisation',
                subtitle: 'Indispensable pour mesurer la consommation.',
                badge: const _StatusPill(ok: true, label: 'Accordé'),
                onTap: controller.openUsageSettings,
              ),
              _SettingRow(
                icon: Icons.notifications_none_rounded,
                title: 'Alertes de consommation',
                subtitle: !settings.notificationsEnabled
                    ? 'Désactivées : aucun seuil ne sera signalé.'
                    : device.notificationsAllowed
                    ? 'Une notification par seuil atteint.'
                    : 'Android bloque les notifications de DataWatch.',
                trailing: Switch(
                  value: settings.notificationsEnabled,
                  onChanged: controller.setNotificationsEnabled,
                ),
                onTap: () => controller.setNotificationsEnabled(
                  !settings.notificationsEnabled,
                ),
              ),
              if (settings.notificationsEnabled && !device.notificationsAllowed)
                _ActionNotice(
                  text:
                      'Autorisez les notifications pour recevoir les alertes.',
                  action: 'Autoriser',
                  onPressed: allowNotifications,
                ),
              _SettingRow(
                icon: Icons.bolt_rounded,
                title: 'Alertes en arrière-plan',
                subtitle: device.backgroundUnrestricted
                    ? 'Android laisse DataWatch vérifier vos seuils à l’heure.'
                    : 'L’économie d’énergie peut retarder les alertes. Choisissez « Aucune restriction » pour DataWatch.',
                badge: _StatusPill(
                  ok: device.backgroundUnrestricted,
                  label: device.backgroundUnrestricted ? 'Fiables' : 'Limitées',
                ),
                onTap: controller.openBatterySettings,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Group(
            title: 'Forfait',
            children: [
              _SettingRow(
                icon: Icons.sim_card_outlined,
                title: 'Modifier le forfait',
                subtitle: plan == null
                    ? 'Aucun forfait déclaré'
                    : '${plan.operator.label} · ${formatBytes(plan.volumeBytes)} · jusqu’au ${formatDayMonthTime(plan.end)}',
                trailing: const _Chevron(),
                onTap: openPlan,
              ),
              _SettingRow(
                icon: Icons.tune_rounded,
                title: 'Seuils d’alerte',
                subtitle: thresholds.isEmpty
                    ? 'Aucun seuil actif'
                    : thresholds.map((p) => '$p$nbsp%').join(' · '),
                trailing: const _Chevron(),
                onTap: openPlan,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Group(
            title: 'Affichage',
            children: [
              _SettingRow(
                icon: Icons.straighten_rounded,
                title: 'Unités',
                subtitle: switch (settings.units) {
                  UnitMode.auto => 'Mo sous 1 Go, Go au-delà',
                  UnitMode.mo => 'Toujours en mégaoctets',
                  UnitMode.go => 'Toujours en gigaoctets',
                },
                below: DwSegmented<UnitMode>(
                  values: UnitMode.values,
                  selected: settings.units,
                  expand: true,
                  height: 34,
                  trackColor: c.background,
                  labelOf: (u) => u.label,
                  onChanged: controller.setUnits,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Group(
            title: 'Informations',
            children: [
              _SettingRow(
                icon: Icons.info_outline_rounded,
                title: 'Comment la mesure fonctionne',
                subtitle:
                    'Pourquoi l’estimation peut différer du solde officiel',
                trailing: const _Chevron(),
                onTap: () =>
                    Navigator.of(context).push(InfoScreen.measurement()),
              ),
              _SettingRow(
                icon: Icons.description_outlined,
                title: 'Politique de confidentialité',
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context).push(InfoScreen.privacy()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Group(
            title: 'Données',
            children: [
              _SettingRow(
                icon: Icons.delete_outline_rounded,
                title: 'Effacer les données locales',
                subtitle:
                    'Forfait, seuils, préférences et historique des alertes',
                destructive: true,
                onTap: eraseAll,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'DataWatch${device.appVersion == null ? '' : ' · version ${device.appVersion}'}',
            textAlign: TextAlign.center,
            style: DwFonts.style(
              DwFonts.mono,
              12,
              400,
            ).copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Données traitées uniquement sur ce téléphone',
            textAlign: TextAlign.center,
            style: t.bodySmall!.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    return Material(
      color: c.hero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DwRadius.xl),
        side: BorderSide(color: c.heroBorder),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(DwRadius.xl),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: DwColors.tankOk,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  size: 22,
                  color: Color(0xFF0F1218),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vos données restent ici.',
                      style: DwFonts.style(
                        DwFonts.display,
                        20,
                        650,
                        letterSpacing: -0.4,
                      ).copyWith(color: c.heroText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tout est calculé sur ce téléphone. Aucune statistique n’est envoyée à un serveur, et aucun compte n’est demandé.',
                      style: t.bodyMedium!.copyWith(
                        color: const Color(0xFFC9CFD9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Semantics(header: true, child: DwOverline(title)),
        ),
        const SizedBox(height: 8),
        DwCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          radius: DwRadius.lg,
          child: Column(
            children: [
              for (final (i, child) in children.indexed)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: i > 0
                        ? Border(top: BorderSide(color: context.dw.divider))
                        : null,
                  ),
                  child: child,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    this.below,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// État affiché sur la ligne du titre (« Accordé », « Limitées »).
  final Widget? badge;

  /// Contrôle large placé sous le texte (sélecteur d'unités).
  final Widget? below;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final color = destructive ? c.critical : c.text;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 21, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: t.bodyLarge!
                                .weight(destructive ? 600 : 500)
                                .copyWith(color: color),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          badge!,
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: t.bodyMedium!.copyWith(color: c.textSecondary),
                      ),
                    ],
                    if (below != null) ...[const SizedBox(height: 10), below!],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Align(heightFactor: 1, child: trailing!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionNotice extends StatelessWidget {
  const _ActionNotice({
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final String text;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: c.warningSoft,
          borderRadius: BorderRadius.circular(DwRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: c.warningText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: t.bodyMedium!.copyWith(color: c.text)),
            ),
            TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(foregroundColor: c.warningText),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final fg = ok ? c.positiveText : c.warningText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ok ? c.positiveSoft : c.warningSoft,
        borderRadius: BorderRadius.circular(DwRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_rounded : Icons.error_outline_rounded,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: DwFonts.style(DwFonts.body, 12.5, 600).copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.chevron_right_rounded, color: context.dw.textSecondary);
}
