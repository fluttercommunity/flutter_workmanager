import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    Workmanager.initialize();
    print("initialized");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: RaisedButton(
            child: Text("Register One off task"),
            onPressed: () {
              Workmanager.registerSampleTask("uniqueName", "This will be the value that will be returned from native");
            },
          ),
        ),
      ),
    );
  }
}
