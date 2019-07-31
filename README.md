# Flutter Workmanager
[![pub package](https://img.shields.io/pub/v/workmanager.svg)](https://pub.dartlang.org/packages/workmanager)

Flutter WorkManager is a wrapper around [Android's WorkManager](https://developer.android.com/topic/libraries/architecture/workmanager).  
It allows for headless background work to be processed in Dart.  

An example of where this would be handy is when you have periodic job that fetches the latest articles every hour.  

> Note that this library only contains the necessary code to let this work on Android. Since iOS has a vastly different approach you should therefore wrap every call:  
>
> `if (Platform.isAndroid) { ... }`

# Installation

```
dependencies:
  workmanager: ^0.0.6+1
```

Get it

```
flutter pub get
```

Import it

```
import 'package:workmanager/workmanager.dart';
```

# How to use

See sample folder for a complete working example.

Before you can register any jobs you need to initialize the plugin.

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
    callbackDispatcher, //the top level function.
    isInDebugMode: true //If enabled it will post a notificiation whenever the job is running. Handy for debugging jobs
)
```

> The `callbackDispatcher` needs to be either a static function or a top level function for it to work.
> You should return a boolean value whether the job was successful or not. 

Now you can register two different kinds of background work:
- **One off task**: These run once
- **Periodic tasks**: These run indefinitely with a defined fixed rate

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

You will need to provide a unique name; this comes in handy when you want to cancel this task later on.  
The second parameter is the `String` that will be returned to your `callbackDispatcher` function.  
You can use this `String` to identify which work needs to be done.  

## Customisation
Not every `WorkManager` feature is ported.

### Tagging

You can set the optional `tag` property.  
Handy for cancellation by `tag`.  
This is different from the unique name in that you can group multiple jobs under one tag.  

```
Workmanager.registerOneOffTask("1", "simpleTask", tag: "tag");
```

### Existing Work Policy

What should happen when you schedule the same job twice?  
The default is `KEEP`

```
Workmanager.registerOneOffTask("1", "simpleTask", existingWorkPolicy: ExistingWorkPolicy.append);
```

### Initial Delay

The minimum amount a job should wait before its first run.

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
When a job should fail this specifies the waiting strategy it should use.  
The default is `BackoffPolicy.exponential`.    
You can also specify the delay.  

```
Workmanager.registerOneOffTask("1", "simpleTask", backoffPolicy: BackoffPolicy.exponential, backoffPolicyDelay: Duration(seconds: 10));
```

## Cancellation

You can cancel jobs in different ways.  
### By Tag

If you have provided job with a tag, you can cancel it that way too.  

```
Workmanager.cancelByTag("tag");
```

### By Unique Name
```
Workmanager.cancelByUniqueName("tag");
```

### All

```
Workmanager.cancelAll();
```
