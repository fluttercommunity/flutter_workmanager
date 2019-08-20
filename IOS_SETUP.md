# iOS Installation

Background fetching is very different than from Android's Background Jobs.  
Before anything, make sure you've added the **UIBackgroundModes** key to your project's `Info.plist`:
```xml
<key>UIBackgroundModes</key>
  <array>
    <string>fetch</string>
  </array>
</key>
```


Inside your app's delegate `didFinishLaunchingWithOptions`, set your desired **minimumBackgroundFetchInterval** :


```Swift
class AppDelegate:UIResponder,UIApplicationDelegate{
    func application(_ application:UIApplication,didFinishLaunchingWithOptions launchOptions:[UIApplicationLaunchOptionsKey:Any]?)->Bool{
        // Other intialization code…
        UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60*15))

        return true
    }
}
```

This ensures that the task is ran at most every 15 minutes.

> 📝 Note: this time interval is a minimum; there's no guarantee about how often this will be called.   

---

Wait for iOS to trigger `performFetchWithCompletionHandler`

We don't have any control on how often iOS will allow our app to fetch data in the background;  
The `background fetch` event can however be simulated by running
`Xcode's Debug` > `Simulate Background Fetch`  

In order to know when `Background Fetch` was triggered you should add the `Workmanager.iOSBackgroundTask` case inside your `callbackDispatcher` function.  

```dart
void callbackDispatcher() {
  Workmanager.executeTask((task) {
    switch (task) {
      case Workmanager.iOSBackgroundTask:
        stderr.writeln("The iOS background fetch was triggered");
        break;
    }

    return Future.value(true);
  });
}
```

The plugin provides an `isInDebugMode` flag when initializing the plugin: `Workmanager.initialize(callbackDispatcher, isInDebugMode: true)`  

Once this flag is enabled you will receive a notification whenever a background fetch was triggered.  This way you can keep track whether that task ran successfully or not.

![example of iOS debug notification](.art/ios_debug_notifications.gif)
