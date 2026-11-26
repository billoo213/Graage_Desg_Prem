# MON GARAGE

Application Flutter de suivi automobile personnel.

## Fonctionnalités
- Profil propriétaire et gestion de plusieurs véhicules.
- Relevés kilométriques datés, historisés, modifiables et supprimables.
- Le kilométrage courant du véhicule est recalculé depuis le relevé le plus récent.
- Interventions, historique et rappels par date ou kilométrage.
- Notifications locales Android.
- Stockage local SQLite.

## Migration de la base
La base SQLite passe à la version 3. À la première ouverture après mise à jour, les véhicules existants reçoivent un relevé initial correspondant au kilométrage déjà enregistré. Les profils, véhicules, interventions et rappels sont conservés.

## Actualisation du kilométrage
Depuis l'écran d'accueil, utiliser le bouton « Actualiser le kilométrage » sous la fiche de chaque véhicule. Chaque relevé comporte un kilométrage et une date. Les anciennes saisies peuvent être corrigées. Le kilométrage courant est celui du relevé portant la date la plus récente.

Après retour à l'accueil, les rappels kilométriques sont réévalués à partir du nouveau kilométrage.

## Compilation Android
Le dossier Android est généré dans GitHub Actions avec `flutter create . --platforms=android`. Le workflow configure le desugaring requis par `flutter_local_notifications`, analyse le code et génère l'APK release.
