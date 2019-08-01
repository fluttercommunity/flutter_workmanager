# Flutter Workmanager
[![pub package](https://img.shields.io/pub/v/workmanager.svg)](https://pub.dartlang.org/packages/workmanager)

Flutter WorkManager is a wrapper around [Android's WorkManager](https://developer.android.com/topic/libraries/architecture/workmanager) and [iOS' performFetchWithCompletionHandler](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623125-application), effectively enabling headless execution of Dart code in the background.

This is especially useful to run periodic tasks, such as fetching remote data on a regular basis.

# Installation

```yaml
dependencies:
  workmanager: ^0.0.6+2
```
```shell script
flutter pub get
```
```dart
import 'package:workmanager/workmanager.dart';
```

# Setup
In order for background work to be scheduled correctly you should follow the Android and iOS setup first.  

- [Android Setup](ANDROID_SETUP.md)
- [iOS Setup](IOS_SETUP.md)

# How to use the package?
See sample folder for a complete working example.  
Before registering any task, the WorkManager plugin must be initialized.

```dart
void callbackDispatcher() {
  Workmanager.executeTask((backgroundTask) {
    print("Native called background task: $backgroundTask"); //simpleTask will be emitted here.
    return Future.value(true);
  });
}

void main() {
  Workmanager.initialize(
    callbackDispatcher, // The top level function, aka Flutter entry point
    isInDebugMode: true // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
  );
  Workmanager.registerOneOffTask("1", "simpleTask");
  runApp(MyApp());
}
```

> The `callbackDispatcher` needs to be either a static function or a top level function to be accessible as a Flutter entry point.

--- 

# Customisation (Android only!) 

Two kinds of background tasks can be registered :
- **One off task** : runs only once
- **Periodic tasks** : runs indefinitely on a regular basis

```
// One off task registration
Workmanager.registerOneOffTask(
    "1", 
    "simpleTask"
);

// Periodic task registration
Workmanager.registerPeriodicTask(
    "2", 
    "simplePeriodicTask", 
    frequency: Duration(hours: 1), //When no frequency is provided the default 15 minutes is set.
)
```

Each task must have an **unique name**;  
This allows cancellation of a started task.  
The second parameter is the `String` that will be send to your `callbackDispatcher` function, indicating the task's *type*.  

### Customisation
Not every `Android WorkManager` feature is ported.

#### Tagging

You can set the optional `tag` property.  
Handy for cancellation by `tag`.  
This is different from the unique name in that you can group multiple tasks under one tag.  

```
Workmanager.registerOneOffTask("1", "simpleTask", tag: "tag");
```

#### Existing Work Policy

Indicates the desired behaviour when the same task is scheduled more than once.  
The default is `KEEP`

```
Workmanager.registerOneOffTask("1", "simpleTask", existingWorkPolicy: ExistingWorkPolicy.append);
```

#### Initial Delay

Indicates how along a task should waitbefore its first run.

```
Workmanager.registerOneOffTask("1", "simpleTask", initialDelay: Duration(seconds: 10));
```

#### Constraints

> Not all constraints are mapped.

```
Workmanager.registerOneOffTask(
    "1", 
    "simpleTask", 
    constraints: WorkManagerConstraintConfig(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresCharging: true,
        requiresDeviceIdle: true,
        requiresStorageNotLow: true
    )
);
```

#### BackoffPolicy
Indicates the waiting strategy upon task failure.  
The default is `BackoffPolicy.exponential`.    
You can also specify the delay. 

```
Workmanager.registerOneOffTask("1", "simpleTask", backoffPolicy: BackoffPolicy.exponential, backoffPolicyDelay: Duration(seconds: 10));
```

### Cancellation

A task can be cancelled in different ways :  

#### By Tag

Cancels the task that was previously registered using this **Tag**, if any.  

```
Workmanager.cancelByTag("tag");
```

#### By Unique Name
```
Workmanager.cancelByUniqueName("<MyTask>");
```

#### All

```
Workmanager.cancelAll();
```