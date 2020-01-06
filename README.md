# Flutter Workmanager
[![pub package](https://img.shields.io/pub/v/workmanager.svg)](https://pub.dartlang.org/packages/workmanager)
[![Build status](https://img.shields.io/cirrus/github/vrtdev/flutter_workmanager/master)](https://cirrus-ci.com/github/vrtdev/flutter_workmanager/)
=======

Flutter WorkManager is a wrapper around [Android's WorkManager](https://developer.android.com/topic/libraries/architecture/workmanager) and [iOS' performFetchWithCompletionHandler](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623125-application), effectively enabling headless execution of Dart code in the background.

This is especially useful to run periodic tasks, such as fetching remote data on a regular basis.

> This plugin was featured in this [Medium blogpost](https://medium.com/vrt-digital-studio/flutter-workmanager-81e0cfbd6f6e)

# Installation

```yaml
dependencies:
  workmanager: ^0.2.0
```
```shell script
flutter pub get
```
```dart
import 'package:workmanager/workmanager.dart';
```

# Platform Setup
In order for background work to be scheduled correctly you should follow the Android and iOS setup first.  

- [Android Setup](ANDROID_SETUP.md)
- [iOS Setup](IOS_SETUP.md)

# How to use the package?
See sample folder for a complete working example.  
Before registering any task, the WorkManager plugin must be initialized.

```dart
void callbackDispatcher() {
  Workmanager.executeTask((task, inputData) {
    print("Native called background task: $backgroundTask"); //simpleTask will be emitted here.
    return Future.value(true);
  });
}

void main() {
  Workmanager.initialize(
    callbackDispatcher, // The top level function, aka callbackDispatcher
    isInDebugMode: true // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
  );
  Workmanager.registerOneOffTask("1", "simpleTask"); //Android only (see below)
  runApp(MyApp());
}
```

> The `callbackDispatcher` needs to be either a static function or a top level function to be accessible as a Flutter entry point.

--- 

# Customisation (Android only!) 
Not every `Android WorkManager` feature is ported.

Two kinds of background tasks can be registered :
- **One off task** : runs only once
- **Periodic tasks** : runs indefinitely on a regular basis

```dart
// One off task registration
Workmanager.registerOneOffTask(
    "1", 
    "simpleTask"
);

// Periodic task registration
Workmanager.registerPeriodicTask(
    "2", 
    "simplePeriodicTask", \
    // When no frequency is provided the default 15 minutes is set.
    // Minimum frequency is 15 min. Android will automatically change your frequency to 15 min if you have configured a lower frequency.
    frequency: Duration(hours: 1),
)
```

Each task must have an **unique name**;  
This allows cancellation of a started task.  
The second parameter is the `String` that will be send to your `callbackDispatcher` function, indicating the task's *type*.  

## Tagging

You can set the optional `tag` property.  
Handy for cancellation by `tag`.  
This is different from the unique name in that you can group multiple tasks under one tag.  

```dart
Workmanager.registerOneOffTask("1", "simpleTask", tag: "tag");
```

## Existing Work Policy

Indicates the desired behaviour when the same task is scheduled more than once.  
The default is `KEEP`

```dart
Workmanager.registerOneOffTask("1", "simpleTask", existingWorkPolicy: ExistingWorkPolicy.append);
```

## Initial Delay

Indicates how along a task should waitbefore its first run.

```dart
Workmanager.registerOneOffTask("1", "simpleTask", initialDelay: Duration(seconds: 10));
```

## Constraints

> Not all constraints are mapped.

```dart
Workmanager.registerOneOffTask(
    "1", 
    "simpleTask", 
    constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresCharging: true,
        requiresDeviceIdle: true,
        requiresStorageNotLow: true
    )
);
```

### InputData

Add some input data for your task. Valid value types are: `int`, `bool`, `double`, `String` and their `list`

```dart
 Workmanager.registerOneOffTask(
    "1",
    "simpleTask", 
    inputData: {
    'int': 1,
    'bool': true,
    'double': 1.0,
    'string': 'string',
    'array': [1, 2, 3],
    },
);
```
## BackoffPolicy
Indicates the waiting strategy upon task failure.  
The default is `BackoffPolicy.exponential`.    
You can also specify the delay. 

```dart
Workmanager.registerOneOffTask("1", "simpleTask", backoffPolicy: BackoffPolicy.exponential, backoffPolicyDelay: Duration(seconds: 10));
```

## Cancellation

A task can be cancelled in different ways :  

### By Tag

Cancels the task that was previously registered using this **Tag**, if any.  

```dart
Workmanager.cancelByTag("tag");
```

### By Unique Name

```dart
Workmanager.cancelByUniqueName("<MyTask>");
```

### All

```dart
Workmanager.cancelAll();
```
