import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../ui/screens/home_shell.dart';
import '../ui/screens/onboarding_screen.dart';
import '../ui/theme/app_theme.dart';
import '../ui/theme/tokens.dart';
import 'app_controller.dart';
import 'app_scope.dart';

class DataWatchApp extends StatefulWidget {
  const DataWatchApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<DataWatchApp> createState() => _DataWatchAppState();
}

class _DataWatchAppState extends State<DataWatchApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Au retour des paramètres Android, l'accès a pu changer.
    _lifecycle = AppLifecycleListener(onResume: widget.controller.recheckAccess);
    widget.controller.init();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: widget.controller,
      child: MaterialApp(
        title: 'DataWatch',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (controller.access) {
        AccessState.unknown => ColoredBox(key: const ValueKey('splash'), color: context.dw.background, child: const SizedBox.expand()),
        AccessState.denied => const OnboardingScreen(key: ValueKey('onboarding')),
        AccessState.granted => const HomeShell(key: ValueKey('home')),
      },
    );
  }
}
