# Flutter Workmanager

[![pub package](https://img.shields.io/pub/v/workmanager.svg)](https://pub.dartlang.org/packages/workmanager)
[![Build status](https://img.shields.io/cirrus/github/vrtdev/flutter_workmanager/master)](https://cirrus-ci.com/github/vrtdev/flutter_workmanager/)
=======

Flutter WorkManager is a wrapper around [Android's WorkManager](https://developer.android.com/topic/libraries/architecture/workmanager), [iOS' performFetchWithCompletionHandler](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623125-application) and [iOS BGAppRefreshTask](https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtask), effectively enabling headless execution of Dart code in the background.

This is especially useful to run periodic tasks, such as fetching remote data on a regular basis.

> This plugin was featured in this [Medium blogpost](https://medium.com/vrt-digital-studio/flutter-workmanager-81e0cfbd6f6e)

# Platform Setup

In order for background work to be scheduled correctly you should follow the Android and iOS setup first.

- [Android Setup](https://github.com/fluttercommunity/flutter_workmanager/blob/master/ANDROID_SETUP.md)
- [iOS Setup](https://github.com/fluttercommunity/flutter_workmanager/blob/master/IOS_SETUP.md)

# How to use the package?

See sample folder for a complete working example.  
Before registering any task, the WorkManager plugin must be initialized.

```dart
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    print("Native called background task: $backgroundTask"); //simpleTask will be emitted here.
    return Future.value(true);
  });
}

void main() {
  Workmanager().initialize(
    callbackDispatcher, // The top level function, aka callbackDispatcher
    isInDebugMode: true // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
  );
  Workmanager().registerOneOffTask("1", "simpleTask"); //Android only (see below)
  runApp(MyApp());
}
```

> The `callbackDispatcher` needs to be either a static function or a top level function to be accessible as a Flutter entry point.

The workmanager runs on a separate isolate from the main flutter isolate. Ensure to initialize all dependencies inside the `Workmanager().executeTask`.

##### Debugging tips

Wrap the code inside your `Workmanager().executeTask` in a `try and catch` in order to catch any exceptions thrown.

```dart
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {

    int? totalExecutions;
    final _sharedPreference = await SharedPreferences.getInstance(); //Initialize dependency

    try { //add code execution
      totalExecutions = _sharedPreference.getInt("totalExecutions");
      _sharedPreference.setInt("totalExecutions", totalExecutions == null ? 1 : totalExecutions+1);
    } catch(err) {
      Logger().e(err.toString()); // Logger flutter package, prints error on the debug console
      throw Exception(err);
    }

    return Future.value(true);
  });
}
```

Android tasks are identified using their `taskName`, whereas two default constants are provided for iOS background operations, depending on whether background fetch or BGTaskScheduler is used: `Workmanager.iOSBackgroundTask` & `Workmanager.iOSBackgroundProcessingTask`.

---

# Work Result

The `Workmanager().executeTask(...` block supports 3 possible outcomes:

1. `Future.value(true)`: The task is successful.
2. `Future.value(false)`: The task did not complete successfully and needs to be retried. On Android, the retry is done automatically. On iOS (when using BGTaskScheduler), the retry needs to be scheduled manually.
3. `Future.error(...)`: The task failed.

On Android, the `BackoffPolicy` will configure how `WorkManager` is going to retry the task.

Refer to the example app for a successful, retrying and a failed task.

# Customisation (iOS - BGTaskScheduler only)

iOS supports **One off tasks** with a few basic constraints:

```dart
Workmanager().registerOneOffTask(
  "1", // Ignored on iOS
  simpleTaskKey, // Ignored on iOS
  initialDelay: Duration(minutes: 30),
  constraints: Constraints(
    // connected or metered mark the task as requiring internet
    networkType: NetworkType.connected,
    // require external power
    requiresCharging: true,
  ),
  inputData: ... // fully supported
);
```

Tasks registered this way will appear in the callback dispatcher using as `Workmanager.iOSBackgroundProcessingTask`.

For more information see the [BGTaskScheduler documentation](https://developer.apple.com/documentation/backgroundtasks).

# Customisation (Android)

Not every `Android WorkManager` feature is ported.

Two kinds of background tasks can be registered :

- **One off task** : runs only once
- **Periodic tasks** : runs indefinitely on a regular basis

```dart
// One off task registration
Workmanager().registerOneOffTask(
    "1",
    "simpleTask"
);

// Periodic task registration
Workmanager().registerPeriodicTask(
    "2",
    "simplePeriodicTask",
    // When no frequency is provided the default 15 minutes is set.
    // Minimum frequency is 15 min. Android will automatically change your frequency to 15 min if you have configured a lower frequency.
    frequency: Duration(hours: 1),
)
```

Each task must have an **unique name**;  
This allows cancellation of a started task.  
The second parameter is the `String` that will be send to your `callbackDispatcher` function, indicating the task's _type_.

## Tagging

You can set the optional `tag` property.  
Handy for cancellation by `tag`.  
This is different from the unique name in that you can group multiple tasks under one tag.

```dart
Workmanager().registerOneOffTask("1", "simpleTask", tag: "tag");
```

## Existing Work Policy

Indicates the desired behaviour when the same task is scheduled more than once.  
The default is `KEEP`

```dart
Workmanager().registerOneOffTask("1", "simpleTask", existingWorkPolicy: ExistingWorkPolicy.append);
```

## Initial Delay

Indicates how along a task should waitbefore its first run.

```dart
Workmanager().registerOneOffTask("1", "simpleTask", initialDelay: Duration(seconds: 10));
```

## Constraints

> Constraints are mapped at best effort to each platform. Android's WorkManager supports most of the specific constraints, whereas iOS tasks are limited.

- NetworkType
  Constrains the type of network required for your work to run. For example, Connected. 
  The `NetworkType` lists various network conditions. `.connected` & `.metered` will be mapped to [`requiresNetworkConnectivity`](https://developer.apple.com/documentation/backgroundtasks/bgprocessingtaskrequest/3142242-requiresnetworkconnectivity) on iOS.
- RequiresBatteryNotLow (Android only)
  When set to true, your work will not run if the device is in low battery mode.
  **Enabling the battery saving mode on the android device prevents the job from running**
- RequiresCharging
  When set to true, your work will only run when the device is charging.
- RequiresDeviceIdle (Android only)
  When set to true, this requires the user’s device to be idle before the work will run. This can be useful for running batched operations that might otherwise have a - negative performance impact on other apps running actively on the user’s device.
- RequiresStorageNotLow (Android only)
  When set to true, your work will not run if the user’s storage space on the device is too low.

```dart
Workmanager().registerOneOffTask(
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
 Workmanager().registerOneOffTask(
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
Workmanager().registerOneOffTask("1", "simpleTask", backoffPolicy: BackoffPolicy.exponential, backoffPolicyDelay: Duration(seconds: 10));
```

## Cancellation

A task can be cancelled in different ways :

### By Tag

Cancels the task that was previously registered using this **Tag**, if any.

```dart
Workmanager().cancelByTag("tag");
```

### By Unique Name

```dart
Workmanager().cancelByUniqueName("<MyTask>");
```

### All

```dart
Workmanager().cancelAll();
```
