import 'dart:math' as math;

enum Operator {
  mtn('MTN'),
  moov('Moov'),
  other('Autre');

  const Operator(this.label);
  final String label;
}

/// Forfait déclaré par l'utilisateur. DataWatch ne connaît pas le solde
/// officiel : tout ce qui en découle est une estimation.
class DataPlan {
  const DataPlan({
    required this.operator,
    required this.volumeBytes,
    required this.start,
    required this.end,
    this.thresholds = defaultThresholds,
    this.recurring = false,
  });

  static const Set<int> defaultThresholds = {50, 80, 100};

  final Operator operator;
  final int volumeBytes;
  final DateTime start;
  final DateTime end;

  /// Seuils d'alerte actifs, en pourcentage du volume.
  final Set<int> thresholds;
  final bool recurring;

  Duration get validity => end.difference(start);

  bool isExpired(DateTime now) => !now.isBefore(end);

  /// Fin de la fenêtre de mesure : maintenant, sans dépasser la fin du forfait.
  DateTime measuredUntil(DateTime now) => now.isBefore(end) ? now : end;

  PlanUsage usage(int usedBytes) =>
      PlanUsage(volumeBytes: volumeBytes, usedBytes: usedBytes);

  /// Même forfait, nouvelle période qui commence à [newStart].
  DataPlan restartedAt(DateTime newStart) =>
      copyWith(start: newStart, end: newStart.add(validity));

  DataPlan copyWith({
    Operator? operator,
    int? volumeBytes,
    DateTime? start,
    DateTime? end,
    Set<int>? thresholds,
    bool? recurring,
  }) {
    return DataPlan(
      operator: operator ?? this.operator,
      volumeBytes: volumeBytes ?? this.volumeBytes,
      start: start ?? this.start,
      end: end ?? this.end,
      thresholds: thresholds ?? this.thresholds,
      recurring: recurring ?? this.recurring,
    );
  }

  Map<String, Object?> toJson() => {
    'operator': operator.name,
    'volumeBytes': volumeBytes,
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
    'thresholds': thresholds.toList()..sort(),
    'recurring': recurring,
  };

  factory DataPlan.fromJson(Map<String, Object?> json) {
    return DataPlan(
      operator: Operator.values.firstWhere(
        (o) => o.name == json['operator'],
        orElse: () => Operator.other,
      ),
      volumeBytes: (json['volumeBytes'] as num).toInt(),
      start: DateTime.fromMillisecondsSinceEpoch(
        (json['start'] as num).toInt(),
      ),
      end: DateTime.fromMillisecondsSinceEpoch((json['end'] as num).toInt()),
      thresholds: {
        for (final t in (json['thresholds'] as List? ?? const []))
          (t as num).toInt(),
      },
      recurring: json['recurring'] as bool? ?? false,
    );
  }
}

enum UsageLevel { ok, half, warning, exhausted }

/// Consommation comptabilisée face au volume déclaré.
class PlanUsage {
  PlanUsage({required this.volumeBytes, required int usedBytes})
    : usedBytes = math.max(0, usedBytes);

  final int volumeBytes;
  final int usedBytes;

  /// Volume restant estimé, jamais négatif (règle 5.1 du cahier des charges).
  int get remainingBytes => math.max(0, volumeBytes - usedBytes);

  double get usedFraction =>
      volumeBytes <= 0 ? 1 : (usedBytes / volumeBytes).clamp(0.0, 1.0);

  double get remainingFraction => 1 - usedFraction;

  UsageLevel get level {
    if (volumeBytes <= 0 || usedBytes >= volumeBytes) {
      return UsageLevel.exhausted;
    }
    final f = usedBytes / volumeBytes;
    if (f >= 0.8) return UsageLevel.warning;
    if (f >= 0.5) return UsageLevel.half;
    return UsageLevel.ok;
  }

  /// Seuils actifs déjà franchis, du plus bas au plus haut.
  List<int> reachedThresholds(Set<int> thresholds) {
    final reached = thresholds
        .where((t) => usedBytes * 100 >= volumeBytes * t)
        .toList();
    return reached..sort();
  }
}

/// Ce que donne le rythme de consommation observé depuis le début du forfait.
sealed class PlanPace {
  const PlanPace();
}

/// Trop tôt pour en tirer une tendance.
class PaceUnknown extends PlanPace {
  const PaceUnknown();
}

/// Le forfait tiendra jusqu'à son expiration.
class PaceLastsUntilEnd extends PlanPace {
  const PaceLastsUntilEnd();
}

/// Au rythme actuel, le volume sera épuisé avant l'expiration.
class PaceRunsOut extends PlanPace {
  const PaceRunsOut(this.at);
  final DateTime at;
}

/// Projection linéaire : consommation moyenne depuis le début du forfait,
/// appliquée au volume restant. Il faut au moins [minElapsed] de recul.
PlanPace projectPace(
  DataPlan plan,
  PlanUsage usage,
  DateTime now, {
  Duration minElapsed = const Duration(hours: 3),
}) {
  final elapsed = plan.measuredUntil(now).difference(plan.start);
  if (elapsed < minElapsed || usage.usedBytes <= 0) return const PaceUnknown();
  final bytesPerSecond = usage.usedBytes / elapsed.inSeconds;
  final runsOutAt = now.add(
    Duration(seconds: (usage.remainingBytes / bytesPerSecond).round()),
  );
  return runsOutAt.isBefore(plan.end)
      ? PaceRunsOut(runsOutAt)
      : const PaceLastsUntilEnd();
}
