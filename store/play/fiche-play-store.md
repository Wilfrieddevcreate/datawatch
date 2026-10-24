# Fiche Play Store — DataWatch

Langue par défaut : **français (France) – fr-FR**. Les textes ci-dessous
respectent les limites de la Play Console (vérifiées).

## Fiche principale

### Nom de l'application (30 caractères max)

```
DataWatch – Suivi data mobile
```

### Description courte (80 caractères max)

```
Voyez quelles applis consomment vos données mobiles et suivez votre forfait.
```

### Description complète (4 000 caractères max)

```
DataWatch vous montre où partent vos données mobiles, application par application, et ce qu'il reste sur votre forfait.

Déclarez votre forfait (volume, date de début, validité) : DataWatch le compare à la consommation mesurée par Android et vous prévient avant qu'il ne soit épuisé.

CE QU'IL VOUS RESTE, D'UN COUP D'ŒIL
• Le volume restant estimé et le pourcentage utilisé
• Le rythme : la date à laquelle le forfait sera épuisé si vous continuez ainsi
• La date et l'heure d'expiration de votre forfait

CHAQUE APPLICATION À SA JUSTE PLACE
• Les applications classées de la plus gourmande à la plus sobre
• Données mobiles et Wi-Fi séparées
• L'évolution par rapport à la période précédente
• Le système Android, le partage de connexion et les applications désinstallées ont leur propre ligne : rien ne se cache

LE VRAI COÛT D'UNE HEURE
• Le temps d'écran de chaque application
• Ce que consomme une heure d'utilisation, et la part du forfait que cela représente
• Un tri « Coût par heure » pour repérer les applications les plus chères à utiliser

DES ALERTES AVANT LA PANNE SÈCHE
• Une notification tous les 20 % par défaut, ou à 50, 80 et 100 %
• Vos propres seuils, si vous préférez
• Vérifiées environ toutes les 15 minutes, même application fermée

DES CONSEILS ADAPTÉS
• Des gestes concrets selon vos applications : vidéo, messagerie, navigateur…
• Un accès direct aux réglages Android de chaque application

VOTRE VIE PRIVÉE, RESPECTÉE
• Aucun compte, aucune publicité
• DataWatch ne demande pas l'accès à Internet : vos données ne quittent jamais votre téléphone
• Il ne lit ni vos messages, ni vos contacts, ni votre position

BON À SAVOIR
• DataWatch a besoin de l'autorisation « Accès aux données d'utilisation » pour lire les compteurs d'Android. Sur Android 9 et avant, il demande aussi l'autorisation « Téléphone », uniquement pour compter les données mobiles.
• Le volume restant est une estimation calculée à partir du forfait déclaré : seul votre opérateur connaît le solde officiel.
• Double SIM : les données mobiles de toutes vos cartes sont additionnées.
• Android 7.0 ou plus récent. Mode sombre inclus.

Une question ? hello@alopro.net
```

### Notes de version (500 caractères max)

```
Première version de DataWatch :
• consommation des données mobiles et Wi-Fi par application ;
• forfait, volume restant estimé et rythme de consommation ;
• alertes tous les 20 %, même application fermée ;
• temps d'écran et coût d'une heure par application ;
• conseils adaptés à vos applications ;
• mode sombre.
```

## Éléments graphiques

| Champ de la Console | Fichier | Format |
|---|---|---|
| Icône de l'application | `icon-512.png` | 512 × 512, PNG 32 bits |
| Image de présentation | `feature-graphic.png` | 1 024 × 500, PNG 24 bits |
| Captures d'écran (téléphone) | `screenshots/01…07-*.png`, dans l'ordre | 1 080 × 1 920, PNG 24 bits |
| Vidéo (facultatif) | `tool/promo/out/DataWatch-presentation.mp4`, à mettre sur YouTube (public ou non répertoriée) | lien YouTube |

Les captures de tablette sont facultatives : DataWatch vise les téléphones.

## Coordonnées et catégorie

- **Type** : Application · **Catégorie** : Outils
- **Adresse e-mail** : hello@alopro.net
- **Site Web** : https://alopro.net
- **Règles de confidentialité** : la page `docs/politique-de-confidentialite.html`
  publiée sur Render (`render.yaml`) :
  https://datawatch.onrender.com/confidentialite, ou l'adresse exacte affichée
  par Render si ce nom est déjà pris. Elle doit être en ligne avant l'envoi en
  examen.

## Contenu de l'application (Règles et programmes › Contenu de l'application)

| Rubrique | Réponse |
|---|---|
| Règles de confidentialité | l'URL ci-dessus |
| Annonces | Non, l'application ne contient pas d'annonces |
| Accès à l'application | Toutes les fonctionnalités sont disponibles sans restriction (aucun compte) |
| Classification du contenu | Catégorie « Toutes les autres applications » (utilitaires, productivité…) ; répondre **Non** à toutes les questions → PEGI 3 / Tout public |
| Public cible | 18 ans et plus (on peut ajouter 13–17 ans ; éviter les moins de 13 ans, qui imposent le programme Familles) |
| Application d'actualités | Non |
| Fonctionnalités financières | Aucune |
| Applications de santé | Non |
| Application gouvernementale | Non |

### Sécurité des données

DataWatch ne transmet rien hors du téléphone (pas de permission Internet) :
selon Google, des données traitées uniquement sur l'appareil ne sont pas
« collectées ».

- Votre application collecte-t-elle ou partage-t-elle des types de données
  utilisateur obligatoires ? → **Non**
- Résultat affiché sur la fiche : « Aucune donnée collectée » et « Aucune
  donnée partagée avec des tiers ».

### Si la Console demande de justifier une autorisation

- **Accès aux données d'utilisation (`PACKAGE_USAGE_STATS`)** : « Fonction
  principale de l'application : afficher à l'utilisateur la consommation de
  données mobiles et Wi-Fi et le temps d'écran de chaque application installée,
  à partir des statistiques d'Android. Aucune donnée ne quitte l'appareil. »
- **Téléphone (`READ_PHONE_STATE`, Android 9 et avant uniquement)** : « Exigée
  par Android jusqu'à la version 9 pour lire la consommation de données mobiles
  de chaque carte SIM. Aucun appel, journal ou numéro n'est lu. »

## Publication

1. Fichier à envoyer : `build/app/outputs/bundle/release/app-release.aab`
   (`flutter build appbundle --release`), signé avec la clé d'importation.
2. Laisser Google gérer la clé de signature de l'application (« Signature
   d'application par Google Play », proposée par défaut).
3. Compte développeur personnel créé après novembre 2023 : Google exige un
   **test fermé avec au moins 12 testeurs pendant 14 jours** avant la mise en
   production. Un compte d'organisation (Alopro, avec numéro D-U-N-S) n'y est
   pas soumis.
4. Chaque nouvelle version augmente `version:` dans `pubspec.yaml`
   (le nombre après `+` doit toujours croître).
