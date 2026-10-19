import 'package:flutter/services.dart';

enum NetworkKind { mobile, wifi }

/// À qui Android attribue une consommation.
enum UsageOwner {
  app,

  /// uid système (< 10000) : Android, services du constructeur…
  system,

  /// Applications désinstallées depuis.
  removed,

  /// Partage de connexion (point d'accès).
  tethering,

  /// Application dont le paquet n'est pas visible (hors lanceur, Android 11+).
  hidden,
}

class AppUsage {
  const AppUsage({
    required this.owner,
    required this.bytes,
    this.packageName,
    this.label,
    this.category,
  });

  final UsageOwner owner;
  final int bytes;
  final String? packageName;
  final String? label;

  /// Catégorie déclarée par le développeur (video, social…), souvent absente.
  final String? category;

  String get displayName => switch (owner) {
    UsageOwner.app => label ?? packageName ?? 'Application',
    UsageOwner.system => 'Système Android',
    UsageOwner.removed => 'Applications désinstallées',
    UsageOwner.tethering => 'Partage de connexion',
    UsageOwner.hidden => 'Autres services',
  };

  /// Identifiant stable pour les listes et les caches.
  String get key => owner == UsageOwner.app ? 'app:$packageName' : owner.name;
}

class DeviceTotals {
  const DeviceTotals({this.mobileBytes, this.wifiBytes});

  /// Null quand Android ne fournit pas la mesure : on n'invente rien.
  final int? mobileBytes;
  final int? wifiBytes;
}

class UsageAccessDenied implements Exception {
  const UsageAccessDenied();
}

class UsageQueryFailed implements Exception {
  const UsageQueryFailed(this.message);
  final String? message;

  @override
  String toString() => 'UsageQueryFailed: $message';
}

/// Lecture des statistiques réseau d'Android via le canal Kotlin.
class UsageSource {
  const UsageSource();

  static const MethodChannel _channel = MethodChannel(
    'net.alopro.datawatch/usage',
  );

  Future<bool> hasUsageAccess() async =>
      await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;

  /// Ouvre l'écran Android « Accès aux données d'utilisation ».
  Future<bool> openUsageAccessSettings() async =>
      await _channel.invokeMethod<bool>('openUsageAccessSettings') ?? false;

  Future<DeviceTotals> deviceTotals(DateTime start, DateTime end) async {
    final raw = await _guard(
      () => _channel.invokeMapMethod<String, Object?>(
        'getDeviceTotals',
        _range(start, end),
      ),
    );
    return DeviceTotals(
      mobileBytes: (raw?['mobileBytes'] as num?)?.toInt(),
      wifiBytes: (raw?['wifiBytes'] as num?)?.toInt(),
    );
  }

  /// Consommation par application, regroupée et triée de la plus gourmande
  /// à la moins gourmande.
  Future<List<AppUsage>> appUsage(
    NetworkKind network,
    DateTime start,
    DateTime end,
  ) async {
    final raw = await _guard(
      () => _channel.invokeListMethod<Map<Object?, Object?>>('getAppUsage', {
        ..._range(start, end),
        'network': network.name,
      }),
    );
    return aggregate((raw ?? const []).map(_parse));
  }

  Future<Uint8List?> appIcon(String packageName, {int size = 96}) {
    return _channel.invokeMethod<Uint8List>('getAppIcon', {
      'packageName': packageName,
      'size': size,
    });
  }

  /// Fusionne les lignes d'un même propriétaire (uids système multiples,
  /// paquets masqués…) et trie par volume décroissant.
  static List<AppUsage> aggregate(Iterable<AppUsage> rows) {
    final merged = <String, AppUsage>{};
    for (final row in rows) {
      final existing = merged[row.key];
      merged[row.key] = existing == null
          ? row
          : AppUsage(
              owner: row.owner,
              bytes: existing.bytes + row.bytes,
              packageName: existing.packageName,
              label: existing.label,
              category: existing.category,
            );
    }
    return merged.values.where((u) => u.bytes > 0).toList()
      ..sort((a, b) => b.bytes.compareTo(a.bytes));
  }

  static AppUsage _parse(Map<Object?, Object?> m) {
    final rx = (m['rxBytes'] as num?)?.toInt() ?? 0;
    final tx = (m['txBytes'] as num?)?.toInt() ?? 0;
    return AppUsage(
      owner: UsageOwner.values.firstWhere(
        (o) => o.name == m['kind'],
        orElse: () => UsageOwner.hidden,
      ),
      bytes: rx + tx,
      packageName: m['packageName'] as String?,
      label: m['label'] as String?,
      category: m['category'] as String?,
    );
  }

  static Map<String, Object> _range(DateTime start, DateTime end) => {
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
  };

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      if (e.code == 'NO_USAGE_ACCESS') throw const UsageAccessDenied();
      throw UsageQueryFailed(e.message);
    }
  }
}
