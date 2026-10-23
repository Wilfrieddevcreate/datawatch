# Règles R8 de DataWatch (ajoutées automatiquement par Flutter en release).

# WorkManager ouvre sa base Room au démarrage de l'application : Room crée
# WorkDatabase_Impl par réflexion, avec son constructeur sans argument. La règle
# livrée par room-runtime 2.6.1 garde la classe mais pas ce constructeur, et R8
# en mode complet le supprime : l'application se fermait juste après le logo.
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
