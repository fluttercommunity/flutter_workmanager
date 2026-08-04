import 'dart:developer';
import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'web/web_app.dart';

void main() {
  if (kIsWeb) {
    runApp(const WebDemoApp());
  } else {
    runApp(MaterialApp(home: MyApp()));
  }
}

const simpleTaskKey = "dev.fluttercommunity.workmanagerExample.simpleTask";
const rescheduledTaskKey =
    "dev.fluttercommunity.workmanagerExample.rescheduledTask";
const failedTaskKey = "dev.fluttercommunity.workmanagerExample.failedTask";
const simpleDelayedTask =
    "dev.fluttercommunity.workmanagerExample.simpleDelayedTask";
const contentUriTaskKey =
    "dev.fluttercommunity.workmanagerExample.contentUriTask";
const expeditedTaskKey =
    "dev.fluttercommunity.workmanagerExample.expeditedTask";
const simplePeriodicTask =
    "dev.fluttercommunity.workmanagerExample.simplePeriodicTask";
const simplePeriodic1HourTask =
    "dev.fluttercommunity.workmanagerExample.simplePeriodic1HourTask";
const iOSBackgroundAppRefresh =
    "dev.fluttercommunity.workmanagerExample.iOSBackgroundAppRefresh";
const iOSBackgroundProcessingTask =
    "dev.fluttercommunity.workmanagerExample.iOSBackgroundProcessingTask";
const periodicUpdatePolicyTask =
    "dev.fluttercommunity.workmanagerExample.periodicUpdatePolicyTask";
const workInfoTaskKey = "dev.fluttercommunity.workmanagerExample.workInfoTask";
const progressTaskKey = "dev.fluttercommunity.workmanagerExample.progressTask";
final List<String> allTasks = [
  simpleTaskKey,
  rescheduledTaskKey,
  failedTaskKey,
  simpleDelayedTask,
  contentUriTaskKey,
  expeditedTaskKey,
  simplePeriodicTask,
  simplePeriodic1HourTask,
  iOSBackgroundAppRefresh,
  iOSBackgroundProcessingTask,
  periodicUpdatePolicyTask,
  progressTaskKey,
];

// Pragma is mandatory if the App is obfuscated or using Flutter 3.1+
@pragma('vm:entry-point')
void callbackDispatcher() {
  log('callbackDispatcher called');
  Workmanager().executeTask((task, inputData) async {
    log("callbackDispatcher called with task: $task");
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    debugPrint("$task started. inputData = $inputData");
    await prefs.setString(task, 'Last ran at: ${DateTime.now().toString()}');

    switch (task) {
      case simpleTaskKey:
        await prefs.setBool("test", true);
        debugPrint("Bool from prefs: ${prefs.getBool("test")}");
        break;
      case rescheduledTaskKey:
        final key = inputData!['key']!;
        if (prefs.containsKey('unique-$key')) {
          debugPrint('has been running before, task is successful');
          return true;
        } else {
          await prefs.setBool('unique-$key', true);
          debugPrint('reschedule task');
          return false;
        }
      case failedTaskKey:
        debugPrint('failed task');
        return Future.error('failed');
      case simpleDelayedTask:
        debugPrint("$simpleDelayedTask was executed");
        break;
      case contentUriTaskKey:
        debugPrint(
            "$contentUriTaskKey was executed after a content URI change");
        break;
      case expeditedTaskKey:
        debugPrint("$expeditedTaskKey was executed (expedited)");
        break;
      case simplePeriodicTask:
        debugPrint("$simplePeriodicTask was executed");
        break;
      case simplePeriodic1HourTask:
        debugPrint("$simplePeriodic1HourTask was executed");
        break;
      case iOSBackgroundAppRefresh:
        // To test, follow the instructions on https://developer.apple.com/documentation/backgroundtasks/starting_and_terminating_tasks_during_development
        // and https://github.com/fluttercommunity/flutter_workmanager/blob/main/IOS_SETUP.md
        Directory? tempDir = await getTemporaryDirectory();
        String? tempPath = tempDir.path;
        debugPrint(
            "You can access other plugins in the background, for example Directory.getTemporaryDirectory(): $tempPath");
        break;
      case iOSBackgroundProcessingTask:
        // To test, follow the instructions on https://developer.apple.com/documentation/backgroundtasks/starting_and_terminating_tasks_during_development
        // and https://github.com/fluttercommunity/flutter_workmanager/blob/main/IOS_SETUP.md
        // Processing tasks are started by iOS only when phone is idle, hence
        // you need to manually trigger by following the docs and putting the App to background
        await Future<void>.delayed(Duration(seconds: 40));
        debugPrint("$task finished");
        break;
      case periodicUpdatePolicyTask:
        final frequency = inputData?['frequency'] ?? 'unknown';
        debugPrint(
            "$periodicUpdatePolicyTask executed with frequency: $frequency minutes at ${DateTime.now()}");
        break;
      case workInfoTaskKey:
        debugPrint("$workInfoTaskKey executed");
      case progressTaskKey:
        // Long-running foreground service task that reports progress. The app
        // observes the updates through Workmanager().setProgressListener.
        // Without the foreground service config WorkManager would stop this
        // worker after ~10 minutes of execution.
        for (var step = 0; step <= 10; step++) {
          await Workmanager().reportProgress(<String, dynamic>{
            'progress': step / 10,
            'step': step,
            'stage': step == 10 ? 'done' : 'working',
          });
          debugPrint("$progressTaskKey reported progress ${step / 10}");
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        break;
      default:
        return Future.value(false);
    }

    // Return true to indicate that the task was successful
    debugPrint("$task finished successfully");
    return Future.value(true);
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool workmanagerInitialized = false;
  String _prefsString = "empty";
  String _workInfoString = "no query yet";
  int _selectedFrequency = 15; // Default to 15 minutes

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
                      final status = await Permission.backgroundRefresh.status;
                      if (status != PermissionStatus.granted) {
                        if (!context.mounted) return;
                        _showNoPermission(context, status);
                        return;
                      }
                    }
                    if (!workmanagerInitialized) {
                      try {
                        await Workmanager().initialize(callbackDispatcher);
                        // Observe progress updates from long-running tasks
                        // (Android only; a no-op on other platforms).
                        Workmanager()
                            .setProgressListener((uniqueName, progress) {
                          debugPrint(
                              'Progress update for $uniqueName: $progress');
                        });
                      } catch (e) {
                        debugPrint('Error initializing Workmanager: $e');
                        return;
                      }
                      setState(() => workmanagerInitialized = true);
                    }
                  },
                ),
                SizedBox(height: 8),
                Text(
                  "Register task",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),

                // This task runs once.
                // Most likely this will trigger immediately
                ElevatedButton(
                  child: Text("Register OneOff Task"),
                  onPressed: () {
                    Workmanager().registerOneOffTask(
                      simpleTaskKey,
                      simpleTaskKey,
                      inputData: <String, dynamic>{
                        'int': 1,
                        'bool': true,
                        'double': 1.0,
                        'string': 'string',
                        'array': [1, 2, 3],
                        // 'map': {'key': 'value'},
                      },
                    );
                  },
                ),
                ElevatedButton(
                  child: Text("Register rescheduled Task"),
                  onPressed: () {
                    Workmanager().registerOneOffTask(
                      rescheduledTaskKey,
                      rescheduledTaskKey,
                      inputData: <String, dynamic>{
                        'key': Random().nextInt(64000),
                      },
                    );
                  },
                ),
                ElevatedButton(
                  child: Text("Register failed Task"),
                  onPressed: () {
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
                      Workmanager().registerOneOffTask(
                        simpleDelayedTask,
                        simpleDelayedTask,
                        initialDelay: Duration(seconds: 10),
                      );
                    }),
                // This task runs when a content URI changes (Android only).
                // A change to any image in the media store triggers it.
                ElevatedButton(
                  onPressed: Platform.isAndroid
                      ? () {
                          Workmanager().registerOneOffTask(
                            contentUriTaskKey,
                            contentUriTaskKey,
                            constraints: Constraints(
                              contentUriTriggers: [
                                ContentUriTrigger(
                                  uri: 'content://media/external/images/media',
                                  triggerForDescendants: true,
                                ),
                              ],
                            ),
                          );
                        }
                      : null,
                  child: Text("Register Content URI Task (Android)"),
                ),
                // This task runs once with high priority (Android only).
                // On Android 12+ the system runs it as a foreground service
                // managed by WorkManager and shows a notification.
                ElevatedButton(
                  onPressed: Platform.isAndroid
                      ? () {
                          Workmanager().registerOneOffTask(
                            expeditedTaskKey,
                            expeditedTaskKey,
                            expedited: true,
                          );
                        }
                      : null,
                  child: Text("Register expedited task (Android)"),
                ),
                // Long-running task promoted to a foreground service. Reports
                // progress every second; the app prints the updates via the
                // progress listener (see the initialize button above).
                ElevatedButton(
                  onPressed: Platform.isAndroid
                      ? () {
                          Workmanager().registerOneOffTask(
                            progressTaskKey,
                            progressTaskKey,
                            foregroundServiceConfig: ForegroundServiceConfig(
                              notificationTitle: 'Progress demo',
                              notificationText: 'Running with progress updates',
                            ),
                          );
                        }
                      : null,
                  child: Text("Register Foreground Progress Task (Android)"),
                ),
                SizedBox(height: 8),
                Text(
                  "Register periodic task (android only)",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                //This task runs periodically
                //It will wait at least 10 seconds before its first launch
                //Since we have not provided a frequency it will be the default 15 minutes
                ElevatedButton(
                  onPressed: Platform.isAndroid
                      ? () {
                          Workmanager().registerPeriodicTask(
                            simplePeriodicTask,
                            simplePeriodicTask,
                            initialDelay: Duration(seconds: 10),
                          );
                        }
                      : null,
                  child: Text("Register Periodic Task (Android)"),
                ),
                //This task runs periodically
                //It will run about every hour
                ElevatedButton(
                    onPressed: Platform.isAndroid
                        ? () {
                            Workmanager().registerPeriodicTask(
                              simplePeriodic1HourTask,
                              simplePeriodic1HourTask,
                              flexInterval: Duration(minutes: 15),
                              frequency: Duration(hours: 1),
                            );
                          }
                        : null,
                    child: Text("Register 1 hour Periodic Task (Android)")),

                SizedBox(height: 16),
                Text(
                  "Test Periodic Task with UPDATE Policy (Android)",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  "Demonstrates issue #622 fix - changing frequency updates the existing task",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SizedBox(height: 8),
                if (Platform.isAndroid) ...[
                  Row(
                    children: [
                      Text("Frequency: "),
                      Expanded(
                        child: DropdownButton<int>(
                          value: _selectedFrequency,
                          items: [
                            DropdownMenuItem(
                                value: 15, child: Text("15 minutes")),
                            DropdownMenuItem(
                                value: 30, child: Text("30 minutes")),
                            DropdownMenuItem(value: 60, child: Text("1 hour")),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedFrequency = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    child: Text("Register Periodic Task with UPDATE Policy"),
                    onPressed: () {
                      Workmanager().registerPeriodicTask(
                        periodicUpdatePolicyTask,
                        periodicUpdatePolicyTask,
                        frequency: Duration(minutes: _selectedFrequency),
                        initialDelay: Duration(seconds: 10),
                        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
                        inputData: <String, dynamic>{
                          'frequency': _selectedFrequency,
                          'timestamp': DateTime.now().toIso8601String(),
                        },
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              "Registered periodic task with ${_selectedFrequency}min frequency using UPDATE policy"),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
                ],

                SizedBox(height: 16),
                // Currently we cannot provide frequency for iOS, hence it will be
                // minimum 15 minutes after which iOS will reschedule
                ElevatedButton(
                  onPressed: Platform.isIOS
                      ? () async {
                          if (!workmanagerInitialized) {
                            _showNotInitialized();
                            return;
                          }
                          await Workmanager().registerPeriodicTask(
                            iOSBackgroundAppRefresh,
                            iOSBackgroundAppRefresh,
                            initialDelay: Duration(seconds: 10),
                            inputData: <String, dynamic>{}, //ignored on iOS
                          );
                        }
                      : null,
                  child: Text('Register Periodic Background App Refresh (iOS)'),
                ),

                // This task runs only once, to perform a time consuming task at
                // a later time decided by iOS.
                // Processing tasks run only when the device is idle. iOS might
                // terminate any running background processing tasks when the
                // user starts using the device.
                ElevatedButton(
                  onPressed: Platform.isIOS
                      ? () async {
                          if (!workmanagerInitialized) {
                            _showNotInitialized();
                            return;
                          }
                          await Workmanager().registerProcessingTask(
                            iOSBackgroundProcessingTask,
                            iOSBackgroundProcessingTask,
                            initialDelay: Duration(seconds: 20),
                          );
                        }
                      : null,
                  child: Text('Register BackgroundProcessingTask (iOS)'),
                ),
                SizedBox(height: 16),
                Text(
                  "Work status observation",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  "Registers a one-off task, waits for it to run, then queries "
                  "its state via getWorkInfo (Android: WorkManager; "
                  "iOS/macOS: plugin-persisted state)",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                ElevatedButton(
                  child: Text("Register, run & query WorkInfo"),
                  onPressed: () async {
                    if (!workmanagerInitialized) {
                      _showNotInitialized();
                      return;
                    }
                    await Workmanager().registerOneOffTask(
                      workInfoTaskKey,
                      workInfoTaskKey,
                      inputData: <String, dynamic>{'int': 1},
                    );
                    await Future<void>.delayed(const Duration(seconds: 2));
                    final info =
                        await Workmanager().getWorkInfo(workInfoTaskKey);
                    setState(() {
                      _workInfoString =
                          info == null ? 'null (no record)' : info.toString();
                    });
                    debugPrint(
                        'WorkInfo for $workInfoTaskKey: $_workInfoString');
                  },
                ),
                SizedBox(height: 8),
                Text('WorkInfo: $_workInfoString'),
                SizedBox(height: 16),
                ElevatedButton(
                    onPressed: Platform.isAndroid
                        ? () async {
                            final workInfo =
                                await Workmanager().isScheduledByUniqueName(
                              simplePeriodicTask,
                            );
                            debugPrint('isscheduled = $workInfo');
                          }
                        : null,
                    child: Text("isscheduled (Android)")),
                SizedBox(height: 8),
                Text(
                  "Task cancellation",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                ElevatedButton(
                  child: Text("Cancel All"),
                  onPressed: () async {
                    await Workmanager().cancelAll();
                    debugPrint('Cancel all tasks completed');
                  },
                ),
                SizedBox(height: 15),
                ElevatedButton(
                  onPressed: _refreshStats,
                  child: Text('Refresh stats'),
                ),
                SizedBox(height: 10),
                SingleChildScrollView(
                  child: Text(
                    'Task run stats:\n'
                    '${workmanagerInitialized ? '' : 'Workmanager not initialized'}'
                    '\n$_prefsString',
                  ),
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

    if (Platform.isIOS) {
      Workmanager().printScheduledTasks();
    }

    setState(() {});
  }

  void _showNotInitialized() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Workmanager not initialized'),
          content: Text('Workmanager is not initialized, please initialize'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showNoPermission(BuildContext context, PermissionStatus hasPermission) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('No permission'),
          content: Text('Background app refresh is disabled, please enable in '
              'App settings. Status ${hasPermission.name}'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
