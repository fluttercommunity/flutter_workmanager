import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

void main() => runApp(MyApp());

const simpleTaskKey = "be.tramckrijte.workmanagerExample.simpleTask";
const rescheduledTaskKey = "be.tramckrijte.workmanagerExample.rescheduledTask";
const failedTaskKey = "be.tramckrijte.workmanagerExample.failedTask";
const simpleDelayedTask = "be.tramckrijte.workmanagerExample.simpleDelayedTask";
const simplePeriodicTask =
    "be.tramckrijte.workmanagerExample.simplePeriodicTask";
const simplePeriodic1HourTask =
    "be.tramckrijte.workmanagerExample.simplePeriodic1HourTask";
const iOSBackgroundAppRefresh =
    "app.workmanagerExample.iOSBackgroundAppRefresh";

@pragma(
    'vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case simpleTaskKey:
        print("$simpleTaskKey was executed. inputData = $inputData");
        final prefs = await SharedPreferences.getInstance();
        prefs.setBool("test", true);
        print("Bool from prefs: ${prefs.getBool("test")}");
        break;
      case rescheduledTaskKey:
        final key = inputData!['key']!;
        final prefs = await SharedPreferences.getInstance();
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
      case Workmanager.iOSBackgroundTask:
        print("The iOS background fetch was triggered");
        Directory? tempDir = await getTemporaryDirectory();
        String? tempPath = tempDir.path;
        sleep(Duration(seconds: 55));
        print(
            "You can access other plugins in the background, for example Directory.getTemporaryDirectory(): $tempPath");
        break;
      case Workmanager.iOSBackgroundAppRefresh:
        //maximum duration 29seconds - App could perhaps killed by iOS when it takes a longer time than 30 seconds for BGAppRefresh included native work
        print("The iOSBackgroundAppRefresh was triggered");
        sleep(Duration(seconds: 11)); // sleep as sample
        // test on debugger - pause debugger in xcode and enter in terminal:
        // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"app.workmanagerExample.iOSBackgroundAppRefresh"]
        break;
    }
    return Future.value(true);
  });
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool workmanagerInitialized = false;

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
                  style: Theme.of(context).textTheme.headline5,
                ),
                ElevatedButton(
                  child: Text("Start the Flutter background service"),
                  onPressed: () {
                    if (!workmanagerInitialized) {
                      Workmanager().initialize(
                        callbackDispatcher,
                        isInDebugMode: true,
                      );
                      workmanagerInitialized = true;
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
                      Workmanager().initialize(
                        callbackDispatcher,
                        isInDebugMode: true,
                      );
                      workmanagerInitialized = true;
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
                      },
                    );
                  },
                ),
                ElevatedButton(
                    child: Text("Register rescheduled Task"),
                    onPressed: () {
                      if (!workmanagerInitialized) {
                        Workmanager().initialize(
                          callbackDispatcher,
                          isInDebugMode: true,
                        );
                        workmanagerInitialized = true;
                      }
                      Workmanager().registerOneOffTask(
                        rescheduledTaskKey,
                        rescheduledTaskKey,
                        inputData: <String, dynamic>{
                          'key': Random().nextInt(64000),
                        },
                      );
                    }),
                ElevatedButton(
                    child: Text("Register failed Task"),
                    onPressed: () {
                      if (!workmanagerInitialized) {
                        Workmanager().initialize(
                          callbackDispatcher,
                          isInDebugMode: true,
                        );
                        workmanagerInitialized = true;
                      }
                      Workmanager().registerOneOffTask(
                        failedTaskKey,
                        failedTaskKey,
                      );
                    }),
                //This task runs once
                //This wait at least 10 seconds before running
                ElevatedButton(
                    child: Text("Register Delayed OneOff Task"),
                    onPressed: () {
                      if (!workmanagerInitialized) {
                        Workmanager().initialize(
                          callbackDispatcher,
                          isInDebugMode: true,
                        );
                        workmanagerInitialized = true;
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
                              Workmanager().initialize(
                                callbackDispatcher,
                                isInDebugMode: true,
                              );
                              workmanagerInitialized = true;
                            }
                            Workmanager().registerPeriodicTask(
                              simplePeriodicTask,
                              simplePeriodicTask,
                              initialDelay: Duration(seconds: 10),
                            );
                          }
                        : null),
                //This task runs periodically dependening on iOS - there is no safe timing - see Apple doc
                //Since we have not provided a frequency it will be the default 2 minutes
                //register name in info.plist <key>BGTaskSchedulerPermittedIdentifiers</key>
                //register name in iOS - Appdelegate
                ElevatedButton(
                    child:
                        Text("Register Periodic Backgound App Refresh (iOS)"),
                    onPressed: Platform.isIOS
                        ? () {
                            if (!workmanagerInitialized) {
                              Workmanager().initialize(
                                callbackDispatcher,
                                isInDebugMode: true,
                              );
                              workmanagerInitialized = true;
                            }
                            Workmanager().registerPeriodicTask(
                              iOSBackgroundAppRefresh,
                              iOSBackgroundAppRefresh,
                              initialDelay: Duration(seconds: 10), //ignored
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
                              Workmanager().initialize(
                                callbackDispatcher,
                                isInDebugMode: true,
                              );
                              workmanagerInitialized = true;
                            }
                            Workmanager().registerPeriodicTask(
                              simplePeriodicTask,
                              simplePeriodic1HourTask,
                              frequency: Duration(hours: 1),
                            );
                          }
                        : null),
                SizedBox(height: 16),
                Text(
                  "Task cancellation",
                  style: Theme.of(context).textTheme.headline5,
                ),
                ElevatedButton(
                  child: Text("Cancel All"),
                  onPressed: () async {
                    await Workmanager().cancelAll();
                    print('Cancel all tasks completed');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
