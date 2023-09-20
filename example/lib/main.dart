import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  runApp(MaterialApp(home: MyApp()));
}

const simpleTaskKey = "be.tramckrijte.workmanagerExample.simpleTask";
const rescheduledTaskKey = "be.tramckrijte.workmanagerExample.rescheduledTask";
const failedTaskKey = "be.tramckrijte.workmanagerExample.failedTask";
const simpleDelayedTask = "be.tramckrijte.workmanagerExample.simpleDelayedTask";
const simplePeriodicTask =
    "be.tramckrijte.workmanagerExample.simplePeriodicTask";
const simplePeriodic1HourTask =
    "be.tramckrijte.workmanagerExample.simplePeriodic1HourTask";
const iOSBackgroundAppRefresh =
    "be.tramckrijte.workmanagerExample.iOSBackgroundAppRefresh";
const iOSBackgroundProcessingTask =
    "be.tramckrijte.workmanagerExample.iOSBackgroundProcessingTask";

final List<String> allTasks = [
  simpleTaskKey,
  rescheduledTaskKey,
  failedTaskKey,
  simpleDelayedTask,
  simplePeriodicTask,
  simplePeriodic1HourTask,
  iOSBackgroundAppRefresh,
  iOSBackgroundProcessingTask,
];

// Pragma is mandatory if the App is obfuscated or using Flutter 3.1+
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    print("$task started. inputData = $inputData");
    await prefs.setString(task, 'Last ran at: ${DateTime.now().toString()}');

    switch (task) {
      case simpleTaskKey:
        await prefs.setBool("test", true);
        print("Bool from prefs: ${prefs.getBool("test")}");
        break;
      case rescheduledTaskKey:
        final key = inputData!['key']!;
        if (prefs.containsKey('unique-$key')) {
          print('has been running before, task is successful');
          return true;
        } else {
          await prefs.setBool('unique-$key', true);
          print('reschedule task');
          return false;
        }
      case failedTaskKey:
        print('failed task');
        return Future.error('failed');
      case simpleDelayedTask:
        print("$simpleDelayedTask was executed");
        break;
      case simplePeriodicTask:
        print("$simplePeriodicTask was executed");
        break;
      case simplePeriodic1HourTask:
        print("$simplePeriodic1HourTask was executed");
        break;
      case iOSBackgroundAppRefresh:
        // Currently fixed value, can't change at the moment - see [BackgroundMode.onResultSendArguments].
        // To test, follow the instructions on https://developer.apple.com/documentation/backgroundtasks/starting_and_terminating_tasks_during_development
        // and https://github.com/fluttercommunity/flutter_workmanager/blob/main/IOS_SETUP.md
        Directory? tempDir = await getTemporaryDirectory();
        String? tempPath = tempDir.path;
        print(
            "You can access other plugins in the background, for example Directory.getTemporaryDirectory(): $tempPath");
        break;
      case iOSBackgroundProcessingTask:
        // Currently fixed value, can't change at the moment - see [BackgroundMode.onResultSendArguments].
        // To test, follow the instructions on https://developer.apple.com/documentation/backgroundtasks/starting_and_terminating_tasks_during_development
        // and https://github.com/fluttercommunity/flutter_workmanager/blob/main/IOS_SETUP.md
        // Processing tasks are started by iOS only when phone is idle, hence
        // you need to manually trigger by following the docs and putting the to
        // background
        await Future<void>.delayed(Duration(seconds: 40));
        print("$task finished");
        break;
      default:
        return Future.value(false);
    }
    return Future.value(true);
  });
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool workmanagerInitialized = false;
  String _prefsString = "empty";
  String _lastResumed = DateTime.now().toString();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App came back from background to foreground
      setState(() => _lastResumed = DateTime.now().toString());
      _refreshStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("Flutter WorkManager Example"),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  "Plugin initialization",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                ElevatedButton(
                  child: Text("Start the Flutter background service"),
                  onPressed: () async {
                    if (Platform.isIOS) {
                      // Check whether background refresh is activated in iOS settings
                      var hasPermissions = await Workmanager()
                          .checkBackgroundRefreshPermission();
                      if (hasPermissions !=
                          BackgroundAuthorisationState.available) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: new Text("No permissions alert"),
                              content: new Text(
                                  "no background refresh permissions!!!"),
                              actions: <Widget>[
                                new TextButton(
                                  child: new Text(
                                      "Status is " + hasPermissions.name),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                        return;
                      }
                    }
                    if (!workmanagerInitialized) {
                      Workmanager().initialize(
                        callbackDispatcher,
                        isInDebugMode: true,
                      );
                      setState(() => workmanagerInitialized = true);
                    }
                  },
                ),
                SizedBox(height: 16),

                //This task runs once.
                //Most likely this will trigger immediately
                ElevatedButton(
                  child: Text("Register OneOff Task"),
                  onPressed: () {
                    if (!workmanagerInitialized) {
                      _showNotInitialized();
                      return;
                    }
                    Workmanager().registerOneOffTask(
                      simpleTaskKey,
                      simpleTaskKey,
                      inputData: <String, dynamic>{
                        'int': 1,
                        'bool': true,
                        'double': 1.0,
                        'string': 'string',
                        'array': [1, 2, 3],
                        'timeStamp': DateTime.now().toString()
                      },
                    );
                  },
                ),
                ElevatedButton(
                  child: Text("Register rescheduled Task"),
                  onPressed: () {
                    if (!workmanagerInitialized) {
                      _showNotInitialized();
                      return;
                    }
                    Workmanager().registerOneOffTask(
                      rescheduledTaskKey,
                      rescheduledTaskKey,
                      requiresCharging: false,
                      networkType: NetworkType.not_required,
                      inputData: <String, dynamic>{
                        'key': Random().nextInt(64000),
                        'timeStamp': DateTime.now().toString()
                      },
                    );
                  },
                ),
                ElevatedButton(
                  child: Text("Register failed Task"),
                  onPressed: () {
                    if (!workmanagerInitialized) {
                      _showNotInitialized();
                      return;
                    }
                    Workmanager().registerOneOffTask(
                      failedTaskKey,
                      failedTaskKey,
                    );
                  },
                ),
                //This task runs once
                //This wait at least 10 seconds before running
                ElevatedButton(
                    child: Text("Register Delayed OneOff Task"),
                    onPressed: () {
                      if (!workmanagerInitialized) {
                        _showNotInitialized();
                        return;
                      }
                      Workmanager().registerOneOffTask(
                        simpleDelayedTask,
                        simpleDelayedTask,
                        initialDelay: Duration(seconds: 10),
                      );
                    }),
                SizedBox(height: 8),
                //This task runs periodically
                //It will wait at least 10 seconds before its first launch
                //Since we have not provided a frequency it will be the default 15 minutes
                ElevatedButton(
                    child: Text("Register Periodic Task (Android)"),
                    onPressed: Platform.isAndroid
                        ? () {
                            if (!workmanagerInitialized) {
                              _showNotInitialized();
                              return;
                            }
                            Workmanager().registerPeriodicTask(
                              simplePeriodicTask,
                              simplePeriodicTask,
                              initialDelay: Duration(seconds: 10),
                            );
                          }
                        : null),
                //This task runs periodically
                //It will run about every hour
                ElevatedButton(
                    child: Text("Register 1 hour Periodic Task (Android)"),
                    onPressed: Platform.isAndroid
                        ? () {
                            if (!workmanagerInitialized) {
                              _showNotInitialized();
                              return;
                            }
                            Workmanager().registerPeriodicTask(
                              simplePeriodic1HourTask,
                              simplePeriodic1HourTask,
                              frequency: Duration(hours: 1),
                            );
                          }
                        : null),
                // This task runs periodically depending on iOS - there is no safe timing - see Apple doc
                // Currently we cannot provide frequency for iOS, hence it will be
                // minimum 15 minutes after which iOS will reschedule
                ElevatedButton(
                  child: Text("Register Periodic Background App Refresh (iOS)"),
                  onPressed: Platform.isIOS
                      ? () async {
                          if (!workmanagerInitialized) {
                            _showNotInitialized();
                            return;
                          }
                          await Workmanager().registerPeriodicTask(
                              iOSBackgroundAppRefresh, iOSBackgroundAppRefresh,
                              initialDelay: Duration(seconds: 10),
                              inputData: <String, dynamic>{} //ignored on iOS
                              );
                        }
                      : null,
                ),
                // This task runs only once, to perform a time consuming task at
                // a later time decided by iOS.
                // Processing tasks run only when the device is idle. iOS terminates
                // any background processing tasks running when the user starts
                // using the device.
                ElevatedButton(
                  child: Text("Register BackgroundProcessingTask (iOS)"),
                  onPressed: Platform.isIOS
                      ? () async {
                          if (!workmanagerInitialized) {
                            _showNotInitialized();
                            return;
                          }
                          await Workmanager().registerProcessingTask(
                            iOSBackgroundProcessingTask,
                            iOSBackgroundProcessingTask,
                          );
                        }
                      : null,
                ),
                SizedBox(height: 16),
                Text(
                  "Task cancellation",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                ElevatedButton(
                  child: Text("Cancel All"),
                  onPressed: () async {
                    if (!workmanagerInitialized) {
                      _showNotInitialized();
                      return;
                    }
                    await Workmanager().cancelAll();
                    print('Cancel all tasks completed');
                  },
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: _refreshStats,
                  child: SingleChildScrollView(
                      child: Text(
                    "Task run stats:\nTap here to update\n "
                    "$_prefsString\n Last App resumed at: $_lastResumed",
                  )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Refresh/get saved prefs
  void _refreshStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    _prefsString = '';
    for (final task in allTasks) {
      _prefsString = '$_prefsString \n$task:\n${prefs.getString(task)}\n';
    }

    setState(() {});
  }

  void _showNotInitialized() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: new Text("Workmanager not initialized"),
          content: new Text("Workmanager not initialized"),
          actions: <Widget>[
            new TextButton(
              child: new Text("OK"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
