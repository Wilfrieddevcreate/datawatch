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

## Limites connues

- **Double SIM** : Android 10+ ne permet pas à une application ordinaire de
  distinguer les SIM. Les données mobiles sont le total de toutes les SIM.
- **Granularité** : Android compte par tranches d'environ deux heures. Le début
  d'une période peut inclure un peu de consommation antérieure.
- **Estimation** : le volume restant est calculé à partir du forfait déclaré ;
  ce n'est pas le solde officiel de l'opérateur.
- **Applications masquées** : sans `QUERY_ALL_PACKAGES` (restreinte sur le Play
  Store), les paquets sans icône dans le lanceur sont regroupés dans
  « Autres services ».
- **Android 10 minimum** (`minSdk 29`).

## Polices

Bricolage Grotesque, Geist et Geist Mono sont embarquées (licence SIL OFL 1.1,
voir `assets/fonts/`). Elles ne sont jamais téléchargées au lancement.
