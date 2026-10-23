# DataWatch

Application Android de suivi de la consommation de données mobiles (Bénin, MTN et Moov).
Flutter pour l'interface, Kotlin pour la lecture des statistiques réseau d'Android.

Tout est calculé sur le téléphone : aucune statistique n'est envoyée à un serveur.

## Lancer le projet

```sh
flutter pub get
flutter run            # téléphone Android 10 ou plus branché en USB
flutter test           # tests unitaires
```

L'application demande l'accès « Données d'utilisation » au premier lancement.
Pour l'accorder sans passer par les réglages pendant le développement :

```sh
adb shell appops set net.alopro.datawatch GET_USAGE_STATS allow
```

## Captures d'écran sans téléphone

Les écrans principaux sont rendus avec de fausses données, au format d'un
téléphone de 360 dp (clair, sombre, texte agrandi) :

```sh
flutter test tool/screenshots/screens_test.dart --update-goldens
```

Les images arrivent dans `tool/screenshots/out/` (non versionné). Une erreur
de mise en page fait échouer la capture concernée.

## Vidéo de présentation

Vidéo de 50 s en 1920 × 1080, sans son, construite à partir des vrais écrans de
l'application. Il faut Python (PIL), Chrome, Node et ffmpeg :

```sh
python3 tool/promo/make_icons.py                               # icônes monogrammes
flutter test tool/promo/capture_test.dart --update-goldens     # écrans de l'app
node tool/promo/render.mjs                                     # → tool/promo/out/DataWatch-presentation.mp4
node tool/promo/render.mjs --stills 3.6,14.9                   # images fixes pour relire le design
```

L'animation est décrite dans `tool/promo/video/index.html` : chaque image est
une fonction du temps, le rendu est donc identique d'une machine à l'autre.

## Icône

L'icône adaptative est vectorielle (`android/app/src/main/res/drawable/ic_launcher_*.xml`).
Les PNG de secours et l'icône Play Store (`branding/`) se régénèrent avec :

```sh
python3 tool/branding/generate_icons.py
```

## Alertes de consommation

Les seuils sont vérifiés en Kotlin par WorkManager, environ toutes les
15 minutes, même application fermée et après un redémarrage. Flutter recopie
le forfait et les réglages côté Android (`configureAlerts`) à chaque
changement ; le Worker n'a donc pas besoin de Flutter pour tourner.

- une seule notification par seuil et par forfait (historique remis à zéro
  quand le forfait change) ;
- si plusieurs seuils sont franchis d'un coup, seul le plus haut est notifié ;
- l'autorisation de notifier (Android 13+) est demandée à l'enregistrement
  du forfait ;
- les paramètres signalent si l'économie d'énergie d'Android peut retarder
  les alertes, fréquent sur les TECNO, Infinix et itel.

## Organisation

```
android/app/src/main/kotlin/net/alopro/datawatch/
  usage/      lecture des statistiques (NetworkStatsManager), canal `usage`
  device/     permissions, écrans de réglages, version, canal `device`
  alerts/     configuration, vérification, notification et Worker des alertes

lib/
  core/        unités (1 Go = 1 024 Mo, affichage Auto/Mo/Go), formatage français
  domain/      forfait, restant, rythme, conseils généraux et par application
  data/        canaux natifs, stockage local du forfait et des paramètres
  app/         contrôleur d'état, période précédente, synchronisation des alertes
  ui/          thème « Réservoir », en-têtes, composants et écrans
```

## Choix validés

- **Unités** : 1 Go = 1 024 Mo (`lib/core/units.dart`).
- **Alertes** : une notification tous les 20 % par défaut (20 à 100 %) ; les
  seuils 50 · 80 · 100 % du cahier des charges restent proposés en un geste.
- **Double SIM** : les données mobiles additionnent toutes les cartes SIM ;
  le forfait déclaré est comparé à ce total.
- **Android 7.0 minimum** (`minSdk 24`, le minimum recommandé par Flutter).
  Sur Android 9 et avant, compter les données mobiles exige l'autorisation
  « Téléphone » (identifiant de chaque SIM) : une étape dédiée l'explique au
  premier lancement. Elle n'est jamais demandée à partir d'Android 10.

## Limites connues

- **Granularité** : Android compte par tranches d'environ deux heures ; une
  période qui commence au milieu d'une tranche en reçoit une part au prorata.
- **Estimation** : le volume restant est calculé à partir du forfait déclaré ;
  ce n'est pas le solde officiel de l'opérateur.
- **Applications masquées** : sans `QUERY_ALL_PACKAGES` (restreinte sur le Play
  Store), les paquets sans icône dans le lanceur sont regroupés dans
  « Autres services ».

## Confidentialité

La version de publication ne demande pas l'accès à Internet. La politique de
confidentialité est dans l'application (Paramètres) et en page web à publier
sur alopro.net : `docs/politique-de-confidentialite.html`. Contact :
hello@alopro.net.

## Polices

Bricolage Grotesque, Geist et Geist Mono sont embarquées (licence SIL OFL 1.1,
voir `assets/fonts/`). Elles ne sont jamais téléchargées au lancement.
