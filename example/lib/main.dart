import 'dart:async';

import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'constants.dart';
import 'my_custom_callback_dispatcher.dart';

void main() => runApp(MyApp());

//If you don't provide a customCallbackDispatcher this one will be called for you
void callbackDispatcher() {
  Workmanager.defaultCallbackDispatcher((echoValue) {
    print("hello from the default callbackDispatcher");
    return Future.value(true);
  });
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("Flutter WorkManager Example"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text("Initialize the plugin first",
                  style: Theme.of(context).textTheme.headline),
              RaisedButton(
                  child: Text("Initialize the plugin in debug mode."),
                  onPressed: () {
                    Workmanager.initialize(isInDebugMode: true);
                  }),
              RaisedButton(
                  child: Text(
                      "Initialize the plugin with a custom `callbackDispatcher`."),
                  onPressed: () {
                    Workmanager.initialize(
                      isInDebugMode: true,
                      callbackDispatcher: customCallbackDispatcher,
                    );
                  }),
              Text("One Off Tasks",
                  style: Theme.of(context).textTheme.headline),
              //This job runs once.
              //Most likely this will trigger immediately
              RaisedButton(
                  child: Text("Register OneOff Task"),
                  onPressed: () {
                    Workmanager.registerOneOffTask(
                      "1",
                      simpleTaskKey,
                    );
                  }),
              //This job runs once
              //This wait at least 10 seconds before running
              RaisedButton(
                  child: Text("Register Delayed OneOff Task"),
                  onPressed: () {
                    Workmanager.registerOneOffTask(
                      "2",
                      simpleDelayedTask,
                      initialDelay: Duration(seconds: 10),
                    );
                  }),

              Text("Periodic Tasks",
                  style: Theme.of(context).textTheme.headline),
              //This job runs periodically
              //It will wait at least 10 seconds before its first launch
              //Since we have not provided a frequency it will be the default 15 minutes
              RaisedButton(
                  child: Text("Register Periodic Task"),
                  onPressed: () {
                    Workmanager.registerPeriodicTask(
                      "3",
                      simplePeriodicTask,
                      initialDelay: Duration(seconds: 10),
                    );
                  }),
              //This job runs periodically
              //It will run about every hour
              RaisedButton(
                  child: Text("Register 1 hour Periodic Task"),
                  onPressed: () {
                    Workmanager.registerPeriodicTask(
                      "5",
                      simplePeriodic1HourTask,
                      frequency: Duration(hours: 1),
                    );
                  }),
            ],
          ),
        ),
      ),
    );
  }
}
