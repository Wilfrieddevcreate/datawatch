/// Convention d'unités de toute l'application : 1 Go = 1 024 Mo.
///
/// À valider avec la convention affichée par MTN et Moov. C'est le seul
/// endroit à modifier pour passer en décimal (1 Go = 1 000 Mo).
abstract final class DataUnits {
  static const int base = 1024;
  static const int bytesPerKo = base;
  static const int bytesPerMo = base * base;
  static const int bytesPerGo = base * base * base;
}
