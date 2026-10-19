import 'dart:typed_data';

import 'package:datawatch/core/units.dart';
import 'package:datawatch/data/usage_source.dart';

const _mo = DataUnits.bytesPerMo;

/// Source de données factice pour les captures d'écran : mêmes ordres de
/// grandeur que la maquette, sans téléphone branché.
class FakeUsageSource implements UsageSource {
  FakeUsageSource({this.mobileBytes = 3707 * _mo, this.granted = true});

  /// Consommation mobile renvoyée pour toute période.
  final int mobileBytes;
  final bool granted;

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
    final scale = mobileBytes / (3707 * _mo);
    AppUsage app(
      String label,
      String pkg,
      int mobileMo,
      int wifiMo, {
      String? category,
    }) => AppUsage(
      owner: UsageOwner.app,
      bytes: ((network == NetworkKind.mobile ? mobileMo * scale : wifiMo) * _mo)
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
          bytes: (389 * scale * _mo).round(),
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
  Future<Uint8List?> appIcon(String packageName, {int size = 96}) async => null;
}
