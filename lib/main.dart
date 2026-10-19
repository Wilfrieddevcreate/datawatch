import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Le contenu s'affiche sous les barres système ; les en-têtes gèrent la marge.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(DataWatchApp(controller: AppController()));
}
