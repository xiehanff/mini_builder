import 'package:flutter/material.dart';
import 'package:mini_builder/mini_builder.dart';

import '../features/home/home_page.dart';
import 'app_services.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final DemoAppServices _services = DemoAppServices();

  @override
  void dispose() {
    _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniProvider<DemoAppServices>(
      value: _services,
      child: MaterialApp(
        title: 'MiniBuilder Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const MiniBuilderExamplePage(),
      ),
    );
  }
}
