import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  //added MaterialApp for showdialog
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
    "app.workmanagerExample.iOSBackgroundAppRefresh";

@pragma(
    'vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final prefs = await SharedPreferences.getInstance();
    switch (task) {
      case simpleTaskKey:
        sleep(Duration(seconds: 22)); // sleep as sample
        print("$simpleTaskKey was executed. inputData = $inputData");
        prefs.setBool("test", true);
        print("Bool from prefs: ${prefs.getBool("test")}");
        prefs.setString(
            "simpleTaskKey", (DateTime.now().toString()) + ' data:$inputData');
        break;
      case rescheduledTaskKey:
        final key = inputData!['key']!;
        prefs.setString("rescheduledTaskKey", DateTime.now().toString());
        if (prefs.containsKey('unique-$key')) {
          print('has been running before, task is successful');
          return true;
        } else {
          prefs.setBool('unique-$key', true);
          print('reschedule task');
          return false;
        }
      case failedTaskKey:
        print('failed task');
        prefs.setString("failedTask", DateTime.now().toString());
        return Future.error('failed');
      case simpleDelayedTask:
        print("$simpleDelayedTask was executed");
        prefs.setString("simpleDelayedTask", DateTime.now().toString());
        break;
      case simplePeriodicTask:
        print("$simplePeriodicTask was executed");
        prefs.setString("simplePeriodicTask", DateTime.now().toString());
        break;
      case simplePeriodic1HourTask:
        print("$simplePeriodic1HourTask was executed");
        prefs.setString("simplePeriodic1HourTask", DateTime.now().toString());
        break;
      case Workmanager.iOSBackgroundTask:
        print("The iOS background fetch was triggered");
        sleep(Duration(seconds: 34)); // sleep as sample
        Directory? tempDir = await getTemporaryDirectory();
        String? tempPath = tempDir.path;
        print(
            "You can access other plugins in the background, for example Directory.getTemporaryDirectory(): $tempPath");
        prefs.setString(
            Workmanager.iOSBackgroundTask, DateTime.now().toString());
        break;
      case Workmanager.iOSBackgroundAppRefresh:
        //maximum duration 29seconds - App could perhaps killed by iOS when it takes a longer time than 30 seconds for BGAppRefresh included native work
        print("The iOS-BackgroundAppRefresh was triggered");
        sleep(Duration(seconds: 14)); // sleep as sample
        prefs.setString(
            Workmanager.iOSBackgroundAppRefresh, DateTime.now().toString());
        // test on debugger - pause debugger in xcode and enter in terminal ( Connected with real device )
        // pause app and enter in Terminal:
        // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"app.workmanagerExample.iOSBackgroundAppRefresh"]
        // then resume app
        //expire earlier
        //e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"app.workmanagerExample.iOSBackgroundAppRefresh"]
        break;
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
    if (state == AppLifecycleState.paused) {
      //app switched to Background
    }
    if (state == AppLifecycleState.resumed) {
      //app came back to Foreground sett infotext as example for iOS
      ///TODO implement Android
      final prefs = await SharedPreferences.getInstance();
      var prefKeys = prefs.getKeys();
      var prefsString = "";
      for (var key in prefKeys) {
        prefsString +=
            key.toString() + " : " + prefs.get(key).toString() + "\n";
      }
      setState(() {
        _lastResumed = DateTime.now().toString();
        _prefsString = prefsString;
      });
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
                  style: Theme.of(context).textTheme.headline5,
                ),
                ElevatedButton(
                  child: Text("Start the Flutter background service"),
                  onPressed: () async {
                    if (Platform.isIOS) {
                      //here you can check whether background refresh is activated in iOS settings
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
                //This wait at least 120 seconds before running
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
                        initialDelay: Duration(seconds: 120),
                      );
                    }),
                SizedBox(height: 8),
                //This task runs periodically
                //It will wait at least 120 seconds before its first launch
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
                              initialDelay: Duration(seconds: 120),
                            );
                          }
                        : null),
                //This task runs periodically dependening on iOS - there is no safe timing - see Apple doc
                //Since we have not provided a frequency it will be the default 2 minutes
                //register name in info.plist <key>BGTaskSchedulerPermittedIdentifiers</key>
                //register name in iOS - Appdelegate
                ElevatedButton(
                    child:
                        Text("Register Periodic Background App Refresh (iOS)"),
                    onPressed: Platform.isIOS
                        ? () async {
                            if (!workmanagerInitialized) {
                              Workmanager().initialize(
                                callbackDispatcher,
                                isInDebugMode: true,
                              );
                              workmanagerInitialized = true;
                            }
                            await Workmanager().registerPeriodicTask(
                              iOSBackgroundAppRefresh,
                              iOSBackgroundAppRefresh,
                              initialDelay: Duration(seconds: 120), //ignored
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
                //show entries in prefs on app resume
                Text("SharedPrefs Values(executed timestamps):\n" +
                    _prefsString +
                    "\n" +
                    "Last-app resumed at: " +
                    _lastResumed)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
