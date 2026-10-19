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

## Organisation

```
android/app/src/main/kotlin/net/alopro/datawatch/
  usage/DataUsageChannel.kt   canal Flutter ⇄ Android (thread dédié)
  usage/NetworkUsageReader.kt requêtes NetworkStatsManager
  usage/AppResolver.kt        uid → nom, icône, catégorie de l'application
  usage/UsageAccess.kt        vérification de l'autorisation

lib/
  core/        unités (1 Go = 1 024 Mo) et formatage français
  domain/      forfait, calcul du restant, règles des conseils
  data/        accès au canal natif, stockage local du forfait
  app/         contrôleur d'état, application
  ui/          thème « Réservoir », composants et écrans
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
