import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/app_scope.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/reservoir_gauge.dart';
import '../widgets/usage_row.dart';

/// Premier lancement : utilité de l'application et demande d'accès aux
/// données d'utilisation (parcours du cahier des charges, section 6).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _sentToSettings = false;

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
    // Android 9 et avant : une seconde autorisation, après l'accès aux données.
    final phoneStep =
        controller.usageAccessGranted && controller.phonePermissionNeeded;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Illustration(),
                    const SizedBox(height: 24),
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
    );
  }

  List<Widget> _usageStep(AppController controller) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    return [
      DwOverline(
        controller.phonePermissionNeeded ? 'Étape 1 sur 2' : 'Accès nécessaire',
      ),
      const SizedBox(height: 8),
      Text('Voyez où partent vos données.', style: _titleStyle),
      const SizedBox(height: 10),
      Text(
        'Pour compter ce que consomme chaque application, DataWatch a besoin de l’accès « Données d’utilisation » d’Android.',
        style: t.bodyLarge!.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: 20),
      const _Reassurance(
        icon: Icons.lock_outline_rounded,
        title: 'Tout reste sur votre téléphone',
        subtitle: 'Aucune statistique n’est envoyée sur Internet.',
      ),
      const SizedBox(height: 14),
      const _Reassurance(
        icon: Icons.verified_user_outlined,
        title: 'Ni SMS, ni messages lus',
        subtitle: 'Seuls les volumes de données sont comptés.',
      ),
      const SizedBox(height: 14),
      const _Reassurance(
        icon: Icons.settings_backup_restore_rounded,
        title: 'Réversible à tout moment',
        subtitle: 'Depuis les paramètres d’Android.',
      ),
      const Spacer(),
      const SizedBox(height: 20),
      if (_sentToSettings) ...[
        DwCard(
          color: c.warningSoft,
          padding: const EdgeInsets.all(14),
          radius: DwRadius.md,
          child: Text(
            'L’accès n’est pas encore accordé. Dans la liste, touchez DataWatch puis activez l’autorisation.',
            style: t.bodyMedium!.copyWith(color: c.text),
          ),
        ),
        const SizedBox(height: 12),
      ],
      FilledButton.icon(
        onPressed: _openSettings,
        iconAlignment: IconAlignment.end,
        icon: Icon(Icons.open_in_new_rounded, size: 18, color: c.accent),
        label: const Text('Ouvrir les paramètres Android'),
      ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: controller.recheckAccess,
        child: Text(
          'J’ai accordé l’accès',
          style: TextStyle(color: c.textSecondary),
        ),
      ),
    ];
  }

  List<Widget> _phoneStep(AppController controller) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    return [
      const DwOverline('Étape 2 sur 2'),
      const SizedBox(height: 8),
      Text('Reconnaître vos cartes SIM.', style: _titleStyle),
      const SizedBox(height: 10),
      Text(
        'Sur votre version d’Android, compter les données mobiles demande l’autorisation « Téléphone ». DataWatch s’en sert uniquement pour identifier vos cartes SIM auprès des compteurs d’Android.',
        style: t.bodyLarge!.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: 20),
      const _Reassurance(
        icon: Icons.phone_disabled_outlined,
        title: 'Aucun appel passé ni lu',
        subtitle: 'Ni journal d’appels, ni numéro de téléphone.',
      ),
      const SizedBox(height: 14),
      const _Reassurance(
        icon: Icons.sim_card_outlined,
        title: 'Toutes vos cartes additionnées',
        subtitle: 'Les données mobiles de chaque SIM sont comptées.',
      ),
      const SizedBox(height: 14),
      const _Reassurance(
        icon: Icons.lock_outline_rounded,
        title: 'Tout reste sur votre téléphone',
        subtitle: 'Rien n’est envoyé sur Internet.',
      ),
      const Spacer(),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: controller.requestPhonePermission,
        child: const Text('Autoriser'),
      ),
    ];
  }

  TextStyle get _titleStyle => DwFonts.style(
    DwFonts.display,
    34,
    700,
    height: 1.04,
    letterSpacing: -1.2,
  );
}

class _Reassurance extends StatelessWidget {
  const _Reassurance({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: c.text),
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
    );
  }
}

/// Le réservoir entouré des grandes familles d'usage (pas de chiffres :
/// aucune mesure n'existe encore à ce stade).
class _Illustration extends StatelessWidget {
  const _Illustration();

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          height: 232,
          color: c.hero,
          child: CustomPaint(
            painter: _DotGrid(),
            child: Stack(
              children: [
                const Center(
                  child: ReservoirGauge(
                    remainingFraction: 0.56,
                    fillColor: DwColors.tankOk,
                    width: 104,
                    height: 188,
                    markers: [],
                  ),
                ),
                const Positioned(
                  left: 14,
                  top: 30,
                  child: _Chip(
                    angle: -0.1,
                    icon: Icons.play_circle_outline_rounded,
                    label: 'Vidéo',
                  ),
                ),
                const Positioned(
                  right: 12,
                  top: 84,
                  child: _Chip(
                    angle: 0.09,
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Messagerie',
                  ),
                ),
                const Positioned(
                  left: 26,
                  bottom: 28,
                  child: _Chip(
                    angle: 0.05,
                    icon: Icons.public_rounded,
                    label: 'Réseaux sociaux',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.angle, required this.icon, required this.label});

  final double angle;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FBCB),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: const Color(0xFF3F5A0B)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: DwFonts.style(
                DwFonts.body,
                12.5,
                600,
              ).copyWith(color: const Color(0xFF0F1218)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotGrid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x17FFFFFF);
    for (var y = 7.0; y < size.height; y += 14) {
      for (var x = 7.0; x < size.width; x += 14) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGrid oldDelegate) => false;
}
