# iOS Installation

Background fetching is very different than from Android's Background Jobs.  
Before anything, make sure you've added the **UIBackgroundModes** key to your project's `Info.plist`:
```
<key>UIBackgroundModes</key>
  <array>
    <string>fetch</string>
  </array>
</key>
```


Inside your app's delegate `didFinishLaunchingWithOptions`, set your desired **minimumBackgroundFetchInterval** :


```swift
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        // Other intialization code…
        UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60 * 15))
        
        return true
    }
 
```

This ensures that the task is ran at most every 15 minutes.

> 📝 Note: this time interval is a minimum; there's no guarantee about how often this will be called.   

---

Wait for iOS to trigger `performFetchWithCompletionHandler`

We don't have any control on how often iOS will allow our app to fetch data in the background ; the `background fetch` event can however be simulated by running
`Xcode's Debug` > `Simulate Background Fetch`  

> Note : this feature is broken in Xcode 10.x.
> To ensure your Dart code is executed upon `performFetchWithCompletionHandler`, call this method explicitly when suited.

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
