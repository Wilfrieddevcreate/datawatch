import '../data/usage_source.dart';

enum TipCategory {
  video('Vidéo'),
  messaging('Messagerie'),
  updates('Mises à jour'),
  background('Arrière-plan');

  const TipCategory(this.label);
  final String label;
}

class Tip {
  const Tip({required this.category, required this.title, required this.body, required this.highImpact});

  final TipCategory category;
  final String title;
  final String body;
  final bool highImpact;
}

const List<Tip> allTips = [
  Tip(
    category: TipCategory.video,
    title: 'Baissez la qualité vidéo',
    body: 'En qualité standard plutôt qu’en HD, une vidéo consomme nettement moins de données.',
    highImpact: true,
  ),
  Tip(
    category: TipCategory.video,
    title: 'Coupez la lecture automatique',
    body: 'Dans les fils d’actualité, les vidéos démarrent seules, même quand vous ne les regardez pas.',
    highImpact: true,
  ),
  Tip(
    category: TipCategory.video,
    title: 'Gros téléchargements en Wi-Fi',
    body: 'Films, musique, podcasts : téléchargez-les en Wi-Fi pour les lire ensuite hors connexion.',
    highImpact: true,
  ),
  Tip(
    category: TipCategory.messaging,
    title: 'Médias WhatsApp en Wi-Fi',
    body: 'Réglez le téléchargement automatique des photos et vidéos sur « Wi-Fi uniquement ».',
    highImpact: false,
  ),
  Tip(
    category: TipCategory.updates,
    title: 'Mises à jour en Wi-Fi uniquement',
    body: 'Dans le Play Store, autorisez les mises à jour automatiques des applications seulement en Wi-Fi.',
    highImpact: false,
  ),
  Tip(
    category: TipCategory.background,
    title: 'Surveillez l’arrière-plan',
    body: 'Certaines applications consomment même fermées. Android permet de limiter leurs données en arrière-plan.',
    highImpact: false,
  ),
];

/// Paquets vidéo courants, en complément de la catégorie déclarée par le
/// développeur (souvent absente).
const Set<String> _videoPackages = {
  'com.zhiliaoapp.musically',
  'com.zhiliaoapp.musically.go',
  'com.ss.android.ugc.trill',
  'com.google.android.youtube',
  'com.google.android.apps.youtube.mango',
  'com.netflix.mediaclient',
};

bool isVideoApp(AppUsage app) =>
    app.owner == UsageOwner.app &&
    (app.category == 'video' || _videoPackages.contains(app.packageName));

/// Ce que la carte « Votre plus gros poste » met en avant.
class TipFocus {
  const TipFocus({required this.headline, required this.detail, required this.share, this.category});

  final String headline;
  final String detail;

  /// Part des données mobiles concernée (0–1).
  final double share;

  /// Filtre proposé par le bouton de la carte (null : tous les conseils).
  final TipCategory? category;
}

/// Règle simple : la vidéo d'abord si elle pèse au moins un quart des données
/// mobiles, sinon l'application la plus gourmande.
TipFocus? focusFor(List<AppUsage> mobileApps) {
  final total = mobileApps.fold<int>(0, (sum, a) => sum + a.bytes);
  if (total == 0) return null;

  final video = mobileApps.where(isVideoApp).toList();
  final videoBytes = video.fold<int>(0, (sum, a) => sum + a.bytes);
  final videoShare = videoBytes / total;
  if (videoShare >= 0.25) {
    final names = video.take(2).map((a) => a.displayName).join(' et ');
    return TipFocus(
      headline: 'La vidéo pèse ${(videoShare * 100).round()} % de vos données mobiles.',
      detail: '$names, sur la période affichée.',
      share: videoShare,
      category: TipCategory.video,
    );
  }

  final top = mobileApps.first;
  final share = top.bytes / total;
  return TipFocus(
    headline: '${top.displayName} pèse ${(share * 100).round()} % de vos données mobiles.',
    detail: 'C’est votre plus gros poste sur la période affichée.',
    share: share,
  );
}
