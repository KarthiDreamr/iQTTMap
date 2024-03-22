import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'client_actions.dart';
import 'mapbox_view.dart';

// @pragma(
//     'vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) {
//     print(
//         "Native called background task: $task"); //simpleTask will be emitted here.
//     return Future.value(true);
//   });
// }

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Workmanager().initialize(
  //     callbackDispatcher, // The top level function, aka callbackDispatcher
  //     isInDebugMode:
  //         true // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
  //     );
  // Workmanager().registerOneOffTask("task-identifier", "simpleTask");

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  Widget build(BuildContext context) {

    return const MaterialApp(
      home: MapboxView()
    );
  }
}

