# Flutter Workmanager
[![pub package](https://img.shields.io/pub/v/workmanager.svg)](https://pub.dartlang.org/packages/workmanager)

Flutter WorkManager is a wrapper around [Android's WorkManager](https://developer.android.com/topic/libraries/architecture/workmanager), with support for [iOS' performFetchWithCompletionHandler](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623125-application), effectively enabling headless execution of Dart code without the need of a running app (i.e. in background).

This is especially useful to run periodic jobs, such as fetching remote data on a regular basis.

# Installation

```
dependencies:
  workmanager: ^0.0.6
```
```
flutter pub get
```
```
import 'package:workmanager/workmanager.dart';
```

# User guide

See sample folder for a complete working example.

Before registering any jobs, the WorkManager plugin must be initialized.

```
//Provide a top level function or static function.
//This function will be called by Android and will return the value you provided when you registered the task.
//See below
void callbackDispatcher() {
  Workmanager.defaultCallbackDispatcher((echoValue) {
    print("Native echoed: $echoValue");
    return Future.value(true);
  });
}

Workmanager.initialize(
    callbackDispatcher, // The top level function, aka Flutter entry point
    isInDebugMode: true // If enabled it will post a notificiation whenever the job is running. Handy for debugging jobs
)
```

> The `callbackDispatcher` needs to be either a static function or a top level function to be accessible as a Flutter entry point. 

## Android usage

Two kinds of background jobs can be registered :
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

Each task must have a **unique name** ; this allows cancellation of a started task.  
The second parameter is the `String` that will be sent to your `callbackDispatcher` function, indicating the task's *type*.  

## Customisation
Not every `Android WorkManager` feature is ported.

### Tagging

You can set the optional `tag` property.  
Handy for cancellation by `tag`.  
This is different from the unique name in that you can group multiple jobs under one tag.  

```
Workmanager.registerOneOffTask("1", "simpleTask", tag: "tag");
```

### Existing Work Policy

Indicates the desired behaviour when the same task is scheduled more than once.  
The default is `KEEP`

```
Workmanager.registerOneOffTask("1", "simpleTask", existingWorkPolicy: ExistingWorkPolicy.append);
```

### Initial Delay

Indicates how along a task should waitbefore its first run.

```
Workmanager.registerOneOffTask("1", "simpleTask", initialDelay: Duration(seconds: 10));
```

### Constraints
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

### BackoffPolicy
Indicates the waiting strategy upon task failure.  
The default is `BackoffPolicy.exponential`.    
You can also specify the delay. 

```
Workmanager.registerOneOffTask("1", "simpleTask", backoffPolicy: BackoffPolicy.exponential, backoffPolicyDelay: Duration(seconds: 10));
```

## Cancellation

A taks can be cancelled in different ways :  
- ##### by Tag

Cancels the task that was previously registered using this **Tag**, if any.  

```
Workmanager.cancelByTag("tag");
```

- ##### by Unique Name
```
Workmanager.cancelByUniqueName("<MyTask>");
```

- ##### cancel all registered tasks

```
Workmanager.cancelAll();
```

## iOS usage

Background taks on iOS are very different. Before anything, make sure you've added the following key to your project's `Info.plist :
```
<key>UIBackgroundModes</key>
  <array>
    <string>fetch</string>
  </array>
</key>
```

#### Set the application's minimumBackgroundFetchInterval

Set your desired *minimumBackgroundFetchInterval* in your app's delegate's `didFinishLaunchingWithOptions` :

`UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60 * 15)) // E.g. max every 15 minutes`
> Note : this time interval is a minimum ; there's no guarantee about how ofteh this will be called. 

#### Adding the plugin as an AppDelegate

This is done automatically by the SwiftWorkManagerPlugin at registration time, by calling [addApplicationDelegate](https://api.flutter.dev/objcdoc/Protocols/FlutterPluginRegistrar.html#/c:objc(pl)FlutterPluginRegistrar(im)addApplicationDelegate:) on the Flutter registrar.

#### Waiting for iOS to trigger `performFetchWithCompletionHandler`

We don't have any control on how often iOS will allow our app to fetch data in the background. The Example Flutter project allows to simulate this event, by pressing the 'Simulate Background Fetch' button (since Xcode's Debug > Simulate Background Fetch doesn't). 
