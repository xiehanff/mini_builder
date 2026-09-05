import 'package:flutter/material.dart';

import 'app/app.dart';
import 'shared/example_log_manager.dart';

void main() {
  ExampleLogManager.instance.info('app_start', source: 'main');
  runApp(const MyApp());
}
