import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/page_header.dart';
import '../widgets/usage_row.dart';

/// Page de texte en sections (explication de la mesure, confidentialité).
class InfoScreen extends StatelessWidget {
  const InfoScreen({
    super.key,
    required this.title,
    required this.overline,
    required this.intro,
    required this.sections,
    this.footer,
  });

  final String title;
  final String overline;
  final String intro;
  final List<(String, String)> sections;
  final String? footer;

  static Route<void> measurement() => MaterialPageRoute(
    builder: (_) => const InfoScreen(
      title: 'Comment la mesure fonctionne',
      overline: 'Informations',
      intro: 'Ce que DataWatch peut mesurer, et ce qu’il ne peut pas savoir.',
      sections: [
        (
          'D’où viennent les chiffres',
          'Android compte lui-même les données échangées par chaque application. Avec votre autorisation, DataWatch lit ces compteurs et les présente simplement.',
        ),
        (
          'Pourquoi c’est une estimation',
          'Votre opérateur compte la consommation de son côté, avec ses propres règles : arrondis, bonus, forfaits de nuit ou réseaux sociaux illimités. Le volume restant est calculé à partir du forfait que vous avez déclaré. Seul l’opérateur connaît le solde officiel.',
        ),
        (
          'Des compteurs mis à jour par tranches',
          'Android regroupe les mesures par tranches d’environ deux heures et les actualise régulièrement, pas en temps réel. Les derniers mégaoctets peuvent apparaître avec un peu de retard.',
        ),
        (
          'Deux cartes SIM',
          'Android ne permet pas à une application de séparer la consommation de chaque carte SIM. Les données mobiles affichées regroupent toutes vos cartes.',
        ),
        (
          'Les alertes',
          'DataWatch vérifie vos seuils environ toutes les 15 minutes, même application fermée. Si Android limite DataWatch pour économiser la batterie, une alerte peut arriver en retard.',
        ),
        (
          'Ce qui est regroupé',
          'Le système Android, les applications désinstallées et le partage de connexion ont chacun leur ligne. Les applications sans icône sur l’écran d’accueil sont regroupées dans « Autres services ».',
        ),
      ],
    ),
  );

  static Route<void> privacy() => MaterialPageRoute(
    builder: (_) => const InfoScreen(
      title: 'Politique de confidentialité',
      overline: 'Informations',
      intro:
          'DataWatch fonctionne entièrement sur votre téléphone. Aucun compte n’est demandé et aucune statistique n’est envoyée à un serveur.',
      sections: [
        (
          'Ce que l’application lit',
          'Avec l’autorisation « Accès aux données d’utilisation », DataWatch lit les volumes de données mobiles et Wi-Fi comptés par Android pour chaque application, ainsi que le nom et l’icône des applications installées.',
        ),
        (
          'Ce qu’elle ne lit pas',
          'DataWatch ne lit ni vos SMS, ni vos messages, ni vos contacts, ni le contenu de vos échanges, ni votre position. Il ne connaît pas votre solde chez l’opérateur.',
        ),
        (
          'Ce qui est enregistré',
          'Le forfait que vous déclarez, vos seuils d’alerte, vos préférences d’affichage et la liste des alertes déjà envoyées. Ces informations restent sur ce téléphone.',
        ),
        (
          'Aucun partage',
          'Aucune donnée n’est transmise à des tiers ni utilisée à des fins publicitaires. L’application ne contient ni publicité, ni outil de mesure d’audience.',
        ),
        (
          'Vos choix',
          'Vous pouvez retirer l’accès aux données d’utilisation et les notifications à tout moment dans les paramètres d’Android, et tout effacer avec « Effacer les données locales ». Désinstaller DataWatch supprime aussi ses données.',
        ),
      ],
      footer: 'Dernière mise à jour : 20 octobre 2026',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: DwPage(
        leading: const DwBackButton(),
        title: title,
        overline: overline,
        subtitle: Text(intro),
        children: [
          DwCard(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, (heading, body)) in sections.indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: i > 0
                          ? Border(top: BorderSide(color: c.divider))
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(heading, style: t.titleMedium),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          body,
                          style: t.bodyLarge!.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 16),
            Text(
              footer!,
              textAlign: TextAlign.center,
              style: t.bodySmall!.copyWith(color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
