import 'dart:io';
import 'dart:typed_data';

import 'package:datawatch/core/units.dart';
import 'package:datawatch/data/usage_source.dart';

const _mo = DataUnits.bytesPerMo;

/// Source de données factice pour les captures d'écran : mêmes ordres de
/// grandeur que la maquette, sans téléphone branché.
class FakeUsageSource implements UsageSource {
  FakeUsageSource({
    this.mobileBytes = 3707 * _mo,
    this.granted = true,
    this.iconDir,
  });

  /// Consommation mobile renvoyée pour toute période.
  final int mobileBytes;
  final bool granted;

  /// Dossier d'icônes `<paquet>.png` (vidéo de présentation). Sans dossier,
  /// l'écran affiche le pictogramme générique.
  final String? iconDir;

  @override
  Future<bool> hasUsageAccess() async => granted;

  @override
  Future<bool> openUsageAccessSettings() async => true;

  @override
  Future<DeviceTotals> deviceTotals(DateTime start, DateTime end) async =>
      DeviceTotals(mobileBytes: mobileBytes, wifiBytes: 11674 * _mo);

  @override
  Future<List<AppUsage>> appUsage(
    NetworkKind network,
    DateTime start,
    DateTime end,
  ) async {
    // Période précédente : chaque application évolue différemment.
    final previous = end.isBefore(DateTime(2026, 10, 15, 8, 31));
    const before = {
      'com.zhiliaoapp.musically': 0.85,
      'com.google.android.youtube': 1.06,
      'com.whatsapp': 0.96,
      'com.facebook.katana': 1.14,
      'com.android.chrome': 0.98,
      'com.instagram.android': 1.43,
    };
    final scale = mobileBytes / (3707 * _mo);
    double factor(String pkg) => previous ? before[pkg] ?? 1 : 1;
    var nextUid = 10100;
    AppUsage app(
      String label,
      String pkg,
      int mobileMo,
      int wifiMo, {
      String? category,
    }) => AppUsage(
      owner: UsageOwner.app,
      uid: nextUid++,
      bytes:
          ((network == NetworkKind.mobile
                      ? mobileMo * scale * factor(pkg)
                      : wifiMo * factor(pkg)) *
                  _mo)
              .round(),
      packageName: pkg,
      label: label,
      category: category,
    );
    return UsageSource.aggregate([
      app('TikTok', 'com.zhiliaoapp.musically', 1239, 3891),
      app(
        'YouTube',
        'com.google.android.youtube',
        860,
        2560,
        category: 'video',
      ),
      app('WhatsApp', 'com.whatsapp', 533, 410),
      if (network == NetworkKind.mobile)
        AppUsage(
          owner: UsageOwner.tethering,
          bytes: (389 * scale * (previous ? 0.7 : 1) * _mo).round(),
        ),
      app('Facebook', 'com.facebook.katana', 287, 640, category: 'social'),
      app('Chrome', 'com.android.chrome', 164, 1250),
      app('Instagram', 'com.instagram.android', 98, 520, category: 'social'),
      AppUsage(
        owner: UsageOwner.system,
        bytes: ((network == NetworkKind.mobile ? 71 * scale : 380) * _mo)
            .round(),
      ),
      AppUsage(
        owner: UsageOwner.removed,
        bytes: ((network == NetworkKind.mobile ? 26 * scale : 58) * _mo)
            .round(),
      ),
    ]);
  }

  @override
  Future<Map<String, Duration>> screenTime(
    DateTime start,
    DateTime end,
  ) async => const {
    'com.zhiliaoapp.musically': Duration(hours: 4, minutes: 40),
    'com.google.android.youtube': Duration(hours: 3, minutes: 10),
    'com.whatsapp': Duration(hours: 6, minutes: 20),
    'com.facebook.katana': Duration(hours: 2, minutes: 30),
    'com.android.chrome': Duration(hours: 3),
    'com.instagram.android': Duration(hours: 1, minutes: 20),
  };

  @override
  Future<List<int>> appUsageByRange(
    int uid,
    NetworkKind network,
    List<DateRangeMs> ranges,
  ) async {
    // Une semaine plausible : montée vers le week-end, journée en cours partielle.
    const mo = [96, 131, 188, 242, 315, 276, 178];
    return [for (var i = 0; i < ranges.length; i++) mo[i % mo.length] * _mo];
  }

  @override
  Future<Uint8List?> appIcon(String packageName, {int size = 96}) async {
    final file = iconDir == null ? null : File('$iconDir/$packageName.png');
    return file != null && file.existsSync() ? file.readAsBytesSync() : null;
  }
}
