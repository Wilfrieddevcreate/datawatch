import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(DataWatchApp(controller: AppController()));
}
