/*
 * Copyright (c) 2019-2022 Larry Aasen. All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only call clearSavedSettings() during testing to reset internal values.
  await Upgrader.clearSavedSettings(); // REMOVE this for release builds

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final _upgrader = MyUpgrader();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upgrader Subclass Example',
      home: Scaffold(
          appBar: AppBar(title: const Text('Upgrader Subclass Example')),
          body: UpgradeAlert(
            upgrader: _upgrader,
            child: const Center(child: Text('Checking...')),
          )),
    );
  }
}

/// This class extends / subclasses Upgrader.
class MyUpgrader extends Upgrader {
  MyUpgrader() : super(debugLogging: true);
}
