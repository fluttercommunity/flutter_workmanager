import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';

void main() => runApp(MyApp());

void callbackDispatcher() {
  Workmanager.defaultCallbackDispatcher((echoValue) {
    print("Native echoed: $echoValue");
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
              RaisedButton(
                  child: Text("Start the Flutter background service first"),
                  onPressed: () {
                    Workmanager.initialize(callbackDispatcher,
                        isInDebugMode: true);
                  }),
              RaisedButton(
                  child: Text("Register OneOff Task"),
                  onPressed: () {
                    Workmanager.registerOneOffTask("1", "simpleTask");
                  }),
              RaisedButton(
                  child: Text("Register Periodic Task"),
                  onPressed: () {
                    Workmanager.registerPeriodicTask("2", "simplePeriodicTask");
                  })
            ],
          ),
        ),
      ),
    );
  }
}
