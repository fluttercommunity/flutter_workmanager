import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'log_helper.dart';

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
//Don'T forget to register these two task in info.plist and AppDelegate.swift (iOS)
const iOSBackgroundAppRefresh =
    "app.workmanagerExample.iOSBackgroundAppRefresh";
const iOSBackgroundProcessingTask =
    "app.workmanagerExample.iOSBackgroundProcessingTask";

@pragma(
    'vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("callbackDispatcher for $task called");
    await LogHelper.LogBGTask(data: "callbackDispatcher for $task called");
    final prefs = await SharedPreferences
        .getInstance(); //only working on Android ?! isolates on iOS has incorrect results.
    switch (task) {
      //simpleTaskKey:rescheduledTaskKey:failedTaskKey starts on iOS immediately with a timeout of 30 secs in background
      case simpleTaskKey:
        sleep(Duration(seconds: 12)); // sleep as sample
        print("$simpleTaskKey was executed. inputData = $inputData");
        prefs.setString(
            "simpleTaskKey", (DateTime.now().toString()) + ' data:$inputData');
        LogHelper.LogBGTask(data: 'simpleTaskKey --> data:$inputData');
        break;
      case rescheduledTaskKey:
        if (inputData == null) {
          LogHelper.LogBGTask(data: "Rescheduled Task without inputData");
          sleep(Duration(seconds: 2));
          return Future.value(true);
        }
        final key = inputData['key']!;
        prefs.setString("rescheduledTaskKey", DateTime.now().toString());
        if (prefs.containsKey('unique-$key')) {
          print('has been running before, task is successful');
          return true;
        } else {
          prefs.setBool('unique-$key', true); //perhaps not working on iOS
          print('reschedule task');
          return Future.value(true);
        }
      case failedTaskKey:
        print('failed task');
        prefs.setString("failedTask", DateTime.now().toString());
        LogHelper.LogBGTask(data: 'failedTaskKey --> data:$inputData');
        return Future.error('failed');
      case simpleDelayedTask:
        print("$simpleDelayedTask was executed");
        prefs.setString("simpleDelayedTask", DateTime.now().toString());
        LogHelper.LogBGTask(data: 'simpleDelayedTaskKey --> data:$inputData');
        break;
      case simplePeriodicTask:
        print("$simplePeriodicTask was executed");
        prefs.setString("simplePeriodicTask", DateTime.now().toString());
        LogHelper.LogBGTask(data: 'simplePeriodicTaskKey --> data:$inputData');
        break;
      case simplePeriodic1HourTask:
        print("$simplePeriodic1HourTask was executed");
        prefs.setString("simplePeriodic1HourTask", DateTime.now().toString());
        LogHelper.LogBGTask(
            data: 'simplePeriodic1HourTask --> data:$inputData');
        break;
      case Workmanager
          .BACKGROUND_APPREFRESH_TASK_NAME: //Fixed value can't change at the moment - see [BackgroundMode.onResultSendArguments]
        //maximum duration 29seconds - App could perhaps killed by iOS when it takes a longer time than 30 seconds for BGAppRefresh included native work
        print("The iOS-BackgroundAppRefresh was triggered");
        sleep(Duration(seconds: 14)); // sleep as sample
        await LogHelper.LogBGTask(data: "iOSBackgroundAppRefresh");
        //iOS SharedPrefs does not work, because they will not updated in isolated
        //****
        // prefs.setString(Workmanager.iOSBackgroundAppRefresh, DateTime.now().toString());
        //****
        // test on debugger
        // push home-button an let app enter background
        // pause debugger in xcode and enter in terminal ( Connected with real device )
        // pause app and enter in Terminal:
        // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"app.workmanagerExample.iOSBackgroundAppRefresh"]
        // then resume app
        break;
      case Workmanager
          .BACKGROUND_PROCESSING_TASK_NAME: //Fixed value can't change at the moment - see [BackgroundMode.onResultSendArguments]
        //here you can run a long running process longer than 30 seconds. It will randomly started by iOS-Operating-System
        // test on debugger - pause debugger in xcode and enter in terminal ( Connected with real device )
        // push home-button an let app enter background
        // pause app and enter in Terminal:
        // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"app.workmanagerExample.iOSBackgroundProcessingTask"]
        // then resume app
        print("The iOS-BGProcessingTask was triggered");
        await LogHelper.LogBGTask(data: "iOSBackgroundProcessingTask started");
        sleep(Duration(seconds: 210)); // sleep as sample
        await LogHelper.LogBGTask(
            data: "iOSBackgroundProcessingTask finished (sleep 210 sec)");
        break;
      default:
        print('callbackhandler: unknown task: $task data:$inputData');
        LogHelper.LogBGTask(data: 'unknown task: $task data:$inputData');
        sleep(Duration(seconds: 5));
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
    if (state == AppLifecycleState.paused) {
      //app switched to Background
    }
    if (state == AppLifecycleState.resumed) {
      //app came back to Foreground set infotext in example app
      setState(() {
        _lastResumed = DateTime.now().toString();
      });
      _updatePrefs();
    }
  }

  void _updatePrefs() async {
    var prefsString = "BgDatalog" + "\n";
    var log = await LogHelper.ReadLogBGTask();
    prefsString += log;
    setState(() {
      _prefsString = prefsString;
    });
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
                        isInDebugMode: true, //Show notifications on iOS native
                      );
                      setState(() {
                        workmanagerInitialized = true;
                      });
                    }
                  },
                ),
                SizedBox(height: 5),
                Text(
                  "Sample tasks to start",
                  style: Theme.of(context).textTheme.headline5,
                ),
                //This task runs once.
                //Most likely this will trigger immediately
                ///Immedately start a background fetch with 29sec timeout - specification by iOS
                ElevatedButton(
                  child: Text("Register OneOff Task"),
                  onPressed: workmanagerInitialized
                      ? () {
                          Workmanager().registerOneOffTask(
                            simpleTaskKey,
                            //unique Name - must same as in iOS registered Id in info.plist
                            simpleTaskKey, //ignored on iOS
                            inputData: <String, dynamic>{
                              'int': 1,
                              'bool': true,
                              'double': 1.0,
                              'string': 'string',
                              'array': [1, 2, 3],
                              'timeStamp': DateTime.now().toString()
                            },
                          );
                        }
                      : null,
                ),
                ElevatedButton(
                    child: Text("Register rescheduled Task"),
                    onPressed: workmanagerInitialized
                        ? () {
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
                          }
                        : null),
                ElevatedButton(
                  child: Text("Register failed Task"),
                  onPressed: workmanagerInitialized
                      ? () {
                          Workmanager().registerOneOffTask(
                            failedTaskKey,
                            failedTaskKey,
                          );
                        }
                      : null,
                ),
                //This task runs once
                //This wait at least 120 seconds before running
                ElevatedButton(
                  child: Text("Register Delayed OneOff Task"),
                  onPressed: workmanagerInitialized
                      ? () {
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
                        }
                      : null,
                ),
                SizedBox(height: 8),
                //This task runs periodically
                //It will wait at least 120 seconds before its first launch
                //Since we have not provided a frequency it will be the default 15 minutes
                ElevatedButton(
                    child: Text("Register Periodic Task (Android)"),
                    onPressed: Platform.isAndroid && workmanagerInitialized
                        ? () {
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
                    onPressed: Platform.isIOS && workmanagerInitialized
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
                                inputData: <String, dynamic>{} //ignored on iOS
                                );
                          }
                        : null),
                ElevatedButton(
                    child: Text("Register BackgroundProcessingTask (iOS)"),
                    onPressed: Platform.isIOS && workmanagerInitialized
                        ? () async {
                            if (!workmanagerInitialized) {
                              Workmanager().initialize(
                                callbackDispatcher,
                                isInDebugMode: true,
                              );
                              workmanagerInitialized = true;
                            }
                            await Workmanager()
                                .registeriOSBackgroundProcessingTask(
                                    iOSBackgroundProcessingTask,
                                    iOSBackgroundProcessingTask);
                          }
                        : null),
                //This task runs periodically
                //It will run about every hour
                ElevatedButton(
                    child: Text("Register 1 hour Periodic Task (Android)"),
                    onPressed: Platform.isAndroid && workmanagerInitialized
                        ? () {
                            Workmanager().registerPeriodicTask(
                              simplePeriodic1HourTask,
                              simplePeriodic1HourTask,
                              frequency: Duration(hours: 1),
                            );
                          }
                        : null),
                SizedBox(height: 16),
                Text(
                  "Task cancellation",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                ElevatedButton(
                  child: Text("Cancel All"),
                  onPressed: workmanagerInitialized
                      ? () async {
                          await Workmanager().cancelAll();
                          print('Cancel all tasks completed');
                        }
                      : null,
                ),
                //show entries in prefs on app resume
                GestureDetector(
                  onTap: () {
                    _updatePrefs();
                  },
                  child: SingleChildScrollView(
                      child: Text(
                          "Task Values(executed timestamps):\nTap here to update\n" +
                              _prefsString +
                              "\n" +
                              "Last-app resumed at: " +
                              _lastResumed)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
