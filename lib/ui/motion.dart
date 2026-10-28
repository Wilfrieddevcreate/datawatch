import 'package:flutter/widgets.dart';

/// Interrupteur général des animations continues (vague de la cuve, cascade
/// d'apparition, chargeur). Les captures d'écran le coupent pour que
/// `pumpAndSettle` se termine ; le réglage d'accessibilité d'Android aussi.
abstract final class DwMotion {
  static bool enabled = true;

  static bool on(BuildContext context) =>
      enabled && !MediaQuery.disableAnimationsOf(context);
}
