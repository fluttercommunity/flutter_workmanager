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

#### Wait for iOS to trigger `performFetchWithCompletionHandler`

There's no control on how often iOS will allow the app to fetch data in the background.  
However, the `background fetch` event can be simulated by selecting
`Debug` > `Simulate Background Fetch` in Xcode.

Upon reception of the `background fetch` event, the WorkManager plugin will start a new **Dart isolate**,
using the entrypoint provided by the `initialize` method.

Here's an example of a Flutter entrypoint called `callbackDispatcher`:

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

#### Debug mode
The WorkManager plugin provides an `isInDebugMode` flag when initializing the plugin:

`Workmanager.initialize(callbackDispatcher, isInDebugMode: true)`  

If `isInDebugMode` is `true`, a system notification will be displayed whenever a background fetch was triggered :

![example of iOS debug notification](.art/ios_debug_notifications.gif)

#### Registered plugins
Since the provided Flutter entry point is ran in a dedicated **Dart isolate**, the Flutter plugins which may
have been registered AppDelegate's `didFinishLaunchingWithOptions` (or somewhere else) are unavailable,
since they were registered on a different registry.

In order to know when the Dart isolate has started, the plugin user may make use of the
WorkmanagerPlugin's `setPluginRegistrantCallback` function. For example :

```Swift
class AppDelegate: FlutterAppDelegate {
    /// Registers all pubspec-referenced Flutter plugins in the given registry.  
    static func registerPlugins(with registry: FlutterPluginRegistry) {
            GeneratedPluginRegistrant.register(with: registry)
       }
    
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // ... Initialization code
        
        AppDelegate.registerPlugins(with: self) // Register the app's plugins in the context of a normal run
        
        WorkmanagerPlugin.setPluginRegistrantCallback { registry in  
            // The following code will be called upon WorkmanagerPlugin's registration.
            // Note : all of the app's plugins may not be required in this context ;
            // instead of using GeneratedPluginRegistrant.register(with: registry),
            // you may want to register only specific plugins.
            AppDelegate.registerPlugins(with: registry)
        }
    }
}
``` 
