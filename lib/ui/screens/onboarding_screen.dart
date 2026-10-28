import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/app_scope.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/page_header.dart';
import '../widgets/primitives.dart';
import '../widgets/water_basin.dart';

/// Premier lancement : utilité de l'application et demande d'accès aux
/// données d'utilisation (parcours du cahier des charges, section 6).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _sentToSettings = false;

  static const _basinHeight = 130.0;

  Future<void> _openSettings() async {
    final opened = await AppScope.of(
      context,
    ).openUsageSettings().then((_) => true, onError: (_) => false);
    if (!mounted) return;
    setState(() => _sentToSettings = true);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ouvrez Paramètres › Applications › Accès spécial › Accès aux données d’utilisation.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final c = context.dw;
    // Android 9 et avant : une seconde autorisation, après l'accès aux données.
    final phoneStep =
        controller.usageAccessGranted && controller.phonePermissionNeeded;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  _basinHeight + 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - _basinHeight - 28,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(
                          height: 44,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: DwWordmark(),
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (phoneStep)
                          ..._phoneStep(controller)
                        else
                          ..._usageStep(controller),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DwRadius.xl),
              ),
              child: WaterBasin(
                remainingFraction: 0.56,
                height: _basinHeight,
                basinColor: c.tank,
                riseDuration: const Duration(milliseconds: 2400),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _usageStep(AppController controller) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    return [
      DwReveal(
        child: Text(
          controller.phonePermissionNeeded
              ? 'Étape 1 sur 2'
              : 'Accès nécessaire',
          style: DwFonts.label(c.textSecondary),
        ),
      ),
      const SizedBox(height: 8),
      DwReveal(
        delay: 1,
        child: Text('Voyez où partent vos données.', style: DwFonts.title(40)),
      ),
      const SizedBox(height: 12),
      DwReveal(
        delay: 2,
        child: Text(
          'Pour compter ce que consomme chaque application, DataWatch a besoin de l’accès « Données d’utilisation » d’Android.',
          style: t.bodyLarge!.copyWith(color: c.textSecondary),
        ),
      ),
      const SizedBox(height: 24),
      const DwReveal(
        delay: 3,
        child: Column(
          children: [
            _Reassurance(
              title: 'Tout reste sur votre téléphone',
              subtitle: 'Aucune statistique n’est envoyée sur Internet.',
            ),
            _Reassurance(
              title: 'Ni SMS, ni messages lus',
              subtitle: 'Seuls les volumes de données sont comptés.',
            ),
            _Reassurance(
              title: 'Réversible à tout moment',
              subtitle: 'Depuis les paramètres d’Android.',
            ),
          ],
        ),
      ),
      const Spacer(),
      const SizedBox(height: 20),
      if (_sentToSettings) ...[
        DwSheet(
          color: c.warningSoft,
          padding: const EdgeInsets.all(14),
          radius: DwRadius.sm,
          child: Text(
            'L’accès n’est pas encore accordé. Dans la liste, touchez DataWatch puis activez l’autorisation.',
            style: t.bodyMedium!.copyWith(color: c.text),
          ),
        ),
        const SizedBox(height: 12),
      ],
      DwReveal(
        delay: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DwPrimaryButton(
              label: 'Ouvrir les paramètres Android',
              trailingIcon: Icons.open_in_new,
              onPressed: _openSettings,
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: controller.recheckAccess,
              child: Text(
                'J’ai accordé l’accès',
                style: TextStyle(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _phoneStep(AppController controller) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    return [
      Text('Étape 2 sur 2', style: DwFonts.label(c.textSecondary)),
      const SizedBox(height: 8),
      Text('Reconnaître vos cartes SIM.', style: DwFonts.title(40)),
      const SizedBox(height: 12),
      Text(
        'Sur votre version d’Android, compter les données mobiles demande l’autorisation « Téléphone ». DataWatch s’en sert uniquement pour identifier vos cartes SIM auprès des compteurs d’Android.',
        style: t.bodyLarge!.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: 24),
      const _Reassurance(
        title: 'Aucun appel passé ni lu',
        subtitle: 'Ni journal d’appels, ni numéro de téléphone.',
      ),
      const _Reassurance(
        title: 'Toutes vos cartes additionnées',
        subtitle: 'Les données mobiles de chaque SIM sont comptées.',
      ),
      const _Reassurance(
        title: 'Tout reste sur votre téléphone',
        subtitle: 'Rien n’est envoyé sur Internet.',
      ),
      const Spacer(),
      const SizedBox(height: 20),
      DwPrimaryButton(
        label: 'Autoriser',
        onPressed: controller.requestPhonePermission,
      ),
    ];
  }
}

class _Reassurance extends StatelessWidget {
  const _Reassurance({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(DwRadius.xs),
            ),
            child: Icon(Icons.check, size: 15, color: c.onAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleMedium),
                Text(
                  subtitle,
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
