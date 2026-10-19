import 'package:flutter/widgets.dart';

import 'app_controller.dart';

/// Rend le contrôleur accessible aux écrans et les reconstruit à chaque changement.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child})
      : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
