# iOS Installation

Background tasks on iOS work very differently than on Android.  
Before anything, make sure you've added the following key to your project's `Info.plist`:
```
<key>UIBackgroundModes</key>
  <array>
    <string>fetch</string>
  </array>
</key>
```

Inside your app's delegate `didFinishLaunchingWithOptions` set your desired _minimumBackgroundFetchInterval_ in your app's delegate's:

//TODO: provide a complete class
```swift
UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60 * 15))  
```

This will ask iOS to schedule the task every 15 minutes.

> 📝 Note: this time interval is a minimum; There's no guarantee about how often this will be called! iOS decides.   

---

Wait for iOS to trigger `performFetchWithCompletionHandler`

We don't have any control on how often iOS will allow our app to fetch data in the background.  
However you can trigger it in XCode Debug menu:   
`Xcode's Debug` > `Simulate Background Fetch`  

> Currently broken in the latest XCode vX.X.X 

In order to know when `Background Fetch` was triggered you should add the `Workmanager.iOSBackgroundTask` case inside your `callbackDispatcher` function.  

```
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
