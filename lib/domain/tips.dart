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
  const Tip({
    required this.category,
    required this.title,
    required this.body,
    required this.highImpact,
  });

  final TipCategory category;
  final String title;
  final String body;
  final bool highImpact;
}

const List<Tip> allTips = [
  Tip(
    category: TipCategory.video,
    title: 'Baissez la qualité vidéo',
    body:
        'En qualité standard plutôt qu’en HD, une vidéo consomme nettement moins de données.',
    highImpact: true,
  ),
  Tip(
    category: TipCategory.video,
    title: 'Coupez la lecture automatique',
    body:
        'Dans les fils d’actualité, les vidéos démarrent seules, même quand vous ne les regardez pas.',
    highImpact: true,
  ),
  Tip(
    category: TipCategory.video,
    title: 'Gros téléchargements en Wi-Fi',
    body:
        'Films, musique, podcasts : téléchargez-les en Wi-Fi pour les lire ensuite hors connexion.',
    highImpact: true,
  ),
  Tip(
    category: TipCategory.messaging,
    title: 'Médias WhatsApp en Wi-Fi',
    body:
        'Réglez le téléchargement automatique des photos et vidéos sur « Wi-Fi uniquement ».',
    highImpact: false,
  ),
  Tip(
    category: TipCategory.updates,
    title: 'Mises à jour en Wi-Fi uniquement',
    body:
        'Dans le Play Store, autorisez les mises à jour automatiques des applications seulement en Wi-Fi.',
    highImpact: false,
  ),
  Tip(
    category: TipCategory.background,
    title: 'Surveillez l’arrière-plan',
    body:
        'Certaines applications consomment même fermées. Android permet de limiter leurs données en arrière-plan.',
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
  const TipFocus({
    required this.headline,
    required this.detail,
    required this.share,
    this.category,
  });

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
      headline:
          'La vidéo pèse ${(videoShare * 100).round()}\u00A0% de vos données mobiles.',
      detail: '$names, sur la période affichée.',
      share: videoShare,
      category: TipCategory.video,
    );
  }

  final top = mobileApps.first;
  final share = top.bytes / total;
  return TipFocus(
    headline:
        '${top.displayName} pèse ${(share * 100).round()}\u00A0% de vos données mobiles.',
    detail: 'C’est votre plus gros poste sur la période affichée.',
    share: share,
  );
}

/// Famille d'usage d'une application, pour choisir des conseils adaptés.
enum AppKind { video, audio, messaging, social, browser, store, other }

const Set<String> _audioPackages = {
  'com.spotify.music',
  'com.afmobi.boomplayer',
  'com.audiomack',
  'deezer.android.app',
};

const Set<String> _messagingPackages = {
  'com.whatsapp',
  'com.whatsapp.w4b',
  'org.telegram.messenger',
  'com.facebook.orca',
  'com.facebook.mlite',
  'com.imo.android.imoim',
  'com.viber.voip',
};

const Set<String> _socialPackages = {
  'com.facebook.katana',
  'com.facebook.lite',
  'com.instagram.android',
  'com.instagram.lite',
  'com.twitter.android',
  'com.snapchat.android',
};

const Set<String> _browserPackages = {
  'com.android.chrome',
  'com.opera.mini.native',
  'com.opera.browser',
  'org.mozilla.firefox',
  'com.transsion.phoenix',
  'com.UCMobile.intl',
  'com.sec.android.app.sbrowser',
  'com.microsoft.emmx',
};

AppKind appKindOf(AppUsage app) {
  final pkg = app.packageName;
  if (isVideoApp(app)) return AppKind.video;
  if (app.category == 'audio' || _audioPackages.contains(pkg)) {
    return AppKind.audio;
  }
  if (_messagingPackages.contains(pkg)) return AppKind.messaging;
  if (app.category == 'social' || _socialPackages.contains(pkg)) {
    return AppKind.social;
  }
  if (_browserPackages.contains(pkg)) return AppKind.browser;
  if (pkg == 'com.android.vending') return AppKind.store;
  return AppKind.other;
}

enum AdviceIcon { video, audio, download, message, browser, wifi, background }

/// Conseil lié à une application précise (écran de détail).
class AppAdvice {
  const AppAdvice(this.icon, this.title, this.body);

  final AdviceIcon icon;
  final String title;
  final String body;
}

/// Deux conseils au plus selon la famille de l'application, puis le réglage
/// Android commun à toutes : les données en arrière-plan. Les conseils restent
/// informatifs : DataWatch ne modifie pas les réglages des autres applications.
List<AppAdvice> adviceFor(AppUsage app, {int? wifiBytes}) {
  final name = app.displayName;
  final specific = switch (appKindOf(app)) {
    AppKind.video => [
      AppAdvice(
        AdviceIcon.video,
        'Baissez la qualité vidéo',
        'Dans les réglages de $name, choisissez une qualité standard ou l’économiseur de données.',
      ),
      const AppAdvice(
        AdviceIcon.video,
        'Coupez la lecture automatique',
        'Les vidéos qui démarrent seules consomment même quand vous ne les regardez pas.',
      ),
    ],
    AppKind.audio => [
      const AppAdvice(
        AdviceIcon.download,
        'Écoutez hors connexion',
        'Téléchargez vos titres en Wi-Fi pour les écouter sans toucher à votre forfait.',
      ),
      const AppAdvice(
        AdviceIcon.audio,
        'Baissez la qualité audio',
        'En données mobiles, une qualité normale suffit le plus souvent.',
      ),
    ],
    AppKind.messaging => [
      AppAdvice(
        AdviceIcon.message,
        'Médias en Wi-Fi uniquement',
        'Dans $name, réglez le téléchargement automatique des photos, vidéos et documents sur « Wi-Fi ».',
      ),
      const AppAdvice(
        AdviceIcon.message,
        'Appels plus légers',
        'Certaines messageries proposent d’utiliser moins de données pendant les appels.',
      ),
    ],
    AppKind.social => [
      AppAdvice(
        AdviceIcon.video,
        'Lecture automatique en Wi-Fi seulement',
        'Dans les réglages de $name, limitez la lecture automatique des vidéos au Wi-Fi.',
      ),
      const AppAdvice(
        AdviceIcon.download,
        'Essayez la version Lite',
        'Quand elle existe, la version Lite d’une application consomme nettement moins.',
      ),
    ],
    AppKind.browser => [
      AppAdvice(
        AdviceIcon.browser,
        'Activez l’économie de données',
        'La plupart des navigateurs, dont $name, proposent un mode qui allège les pages.',
      ),
    ],
    AppKind.store => [
      const AppAdvice(
        AdviceIcon.download,
        'Mises à jour en Wi-Fi uniquement',
        'Dans le Play Store, autorisez les mises à jour automatiques seulement en Wi-Fi.',
      ),
    ],
    AppKind.other => <AppAdvice>[],
  };

  final wifi = wifiBytes != null && wifiBytes > app.bytes * 1.5
      ? AppAdvice(
          AdviceIcon.wifi,
          'Gardez-la pour le Wi-Fi',
          'Vous utilisez déjà surtout $name en Wi-Fi : réservez-y les longues sessions.',
        )
      : null;
  return [
    ...specific.take(wifi == null ? 2 : 1),
    ?wifi,
    AppAdvice(
      AdviceIcon.background,
      'Limitez l’arrière-plan',
      'Dans Android : Applications › $name › Données mobiles, désactivez les données en arrière-plan.',
    ),
  ];
}
