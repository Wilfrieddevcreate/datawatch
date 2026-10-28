import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/app_scope.dart';
import '../../core/format.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/page_header.dart';
import '../widgets/primitives.dart';
import '../widgets/text_tabs.dart';
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
        subtitle: const Text(
          'Autorisations, alertes et données de l’application.',
        ),
        children: [
          DwReveal(
            child: _PrivacySheet(
              onOpen: () => Navigator.of(context).push(InfoScreen.privacy()),
            ),
          ),
          const SizedBox(height: 22),
          DwReveal(
            delay: 1,
            child: _Group(
              title: 'Autorisations',
              children: [
                _SettingRow(
                  title: 'Accès aux données d’utilisation',
                  subtitle: 'Indispensable pour mesurer la consommation.',
                  badge: DwTag(
                    'Accordé',
                    color: c.positiveText,
                    icon: Icons.check,
                  ),
                  onTap: controller.openUsageSettings,
                ),
                _SettingRow(
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
                if (settings.notificationsEnabled &&
                    !device.notificationsAllowed)
                  _ActionNotice(
                    text:
                        'Autorisez les notifications pour recevoir les alertes.',
                    action: 'Autoriser',
                    onPressed: allowNotifications,
                  ),
                _SettingRow(
                  title: 'Alertes en arrière-plan',
                  subtitle: device.backgroundUnrestricted
                      ? 'Android laisse DataWatch vérifier vos seuils à l’heure.'
                      : 'L’économie d’énergie peut retarder les alertes. Choisissez « Aucune restriction » pour DataWatch.',
                  badge: DwTag(
                    device.backgroundUnrestricted ? 'Fiables' : 'Limitées',
                    color: device.backgroundUnrestricted
                        ? c.positiveText
                        : c.warningText,
                    icon: device.backgroundUnrestricted
                        ? Icons.check
                        : Icons.error_outline,
                  ),
                  onTap: controller.openBatterySettings,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          DwReveal(
            delay: 2,
            child: _Group(
              title: 'Forfait',
              children: [
                _SettingRow(
                  title: 'Modifier le forfait',
                  subtitle: plan == null
                      ? 'Aucun forfait déclaré'
                      : '${plan.operator.label} · ${formatBytes(plan.volumeBytes)} · jusqu’au ${formatDayMonthTime(plan.end)}',
                  trailing: const _Chevron(),
                  onTap: openPlan,
                ),
                _SettingRow(
                  title: 'Seuils d’alerte',
                  subtitle: thresholds.isEmpty
                      ? 'Aucun seuil actif'
                      : thresholds.map((p) => '$p$nbsp%').join(' · '),
                  trailing: const _Chevron(),
                  onTap: openPlan,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          DwReveal(
            delay: 3,
            child: _Group(
              title: 'Affichage',
              children: [
                _SettingRow(
                  title: 'Unités',
                  subtitle: switch (settings.units) {
                    UnitMode.auto => 'Mo sous 1 Go, Go au-delà',
                    UnitMode.mo => 'Toujours en mégaoctets',
                    UnitMode.go => 'Toujours en gigaoctets',
                  },
                  trailing: DwChoiceWords<UnitMode>(
                    values: UnitMode.values,
                    selected: settings.units,
                    spacing: 14,
                    labelOf: (u) => u.label,
                    onChanged: controller.setUnits,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          DwReveal(
            delay: 4,
            child: _Group(
              title: 'Informations',
              children: [
                _SettingRow(
                  title: 'Comment la mesure fonctionne',
                  subtitle:
                      'Pourquoi l’estimation peut différer du solde officiel',
                  trailing: const _Chevron(),
                  onTap: () =>
                      Navigator.of(context).push(InfoScreen.measurement()),
                ),
                _SettingRow(
                  title: 'Politique de confidentialité',
                  trailing: const _Chevron(),
                  onTap: () => Navigator.of(context).push(InfoScreen.privacy()),
                ),
                _SettingRow(
                  title: 'Nous écrire',
                  subtitle: publisherEmail,
                  trailing: const _Chevron(),
                  onTap: () => controller.openUrl(
                    'mailto:$publisherEmail?subject=DataWatch',
                  ),
                ),
                _SettingRow(
                  title: 'Site web',
                  subtitle: publisherSite,
                  trailing: const _Chevron(),
                  onTap: () => controller.openUrl('https://$publisherSite'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          DwReveal(
            delay: 5,
            child: _Group(
              title: 'Données',
              children: [
                _SettingRow(
                  title: 'Effacer les données locales',
                  subtitle:
                      'Forfait, seuils, préférences et historique des alertes',
                  destructive: true,
                  onTap: eraseAll,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'DataWatch${device.appVersion == null ? '' : ' · version ${device.appVersion}'} · données traitées uniquement sur ce téléphone',
            textAlign: TextAlign.center,
            style: t.bodySmall!.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PrivacySheet extends StatelessWidget {
  const _PrivacySheet({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    return Material(
      color: c.hero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DwRadius.lg),
        side: BorderSide(color: c.heroBorder),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(DwRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.verified_user_outlined,
                  size: 26,
                  color: c.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vos données restent ici.',
                      style: DwFonts.section(22).copyWith(color: c.heroText),
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
        DwSectionTitle(title, size: 20),
        const SizedBox(height: 10),
        DwSheet(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
    required this.title,
    this.subtitle,
    this.badge,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;

  /// État affiché sur la ligne du titre (« Accordé », « Limitées »).
  final Widget? badge;
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
        constraints: const BoxConstraints(minHeight: 62),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
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
          borderRadius: BorderRadius.circular(DwRadius.sm),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, size: 18, color: c.warningText),
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

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.chevron_right, color: context.dw.textSecondary);
}
