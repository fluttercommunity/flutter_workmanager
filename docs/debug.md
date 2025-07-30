# Debug Hook System

The Workmanager plugin now uses a hook-based debug system instead of the old `isInDebugMode` parameter. This provides more flexibility and allows you to customize how debug information is handled.

## Migration from `isInDebugMode`

**Before:**
```dart
await Workmanager().initialize(
  callbackDispatcher,
  isInDebugMode: true, // ❌ No longer available
);
```

**After:**
```dart
await Workmanager().initialize(callbackDispatcher);
// Debug handling is now platform-specific and optional
```

## Android Debug Handlers

### 1. Logging Debug Handler (Recommended for Development)

Shows debug information in Android's Log system (visible in `adb logcat`):

```kotlin
// In your MainActivity.kt or Application class
import dev.fluttercommunity.workmanager.WorkmanagerDebug
import dev.fluttercommunity.workmanager.LoggingDebugHandler

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enable logging debug handler
        WorkmanagerDebug.setDebugHandler(LoggingDebugHandler())
    }
}
```

### 2. Notification Debug Handler

Shows debug information as notifications (requires notification permissions):

```kotlin
import dev.fluttercommunity.workmanager.WorkmanagerDebug
import dev.fluttercommunity.workmanager.NotificationDebugHandler

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enable notification debug handler
        WorkmanagerDebug.setDebugHandler(NotificationDebugHandler())
    }
}
```

### 3. Custom Debug Handler

Create your own debug handler by implementing `WorkmanagerDebugHandler`:

```kotlin
import dev.fluttercommunity.workmanager.WorkmanagerDebugHandler
import dev.fluttercommunity.workmanager.TaskDebugInfo
import dev.fluttercommunity.workmanager.TaskResult

class CustomDebugHandler : WorkmanagerDebugHandler {
    override fun onTaskStarting(context: Context, taskInfo: TaskDebugInfo) {
        // Your custom logic here
        // e.g., send to analytics, write to file, etc.
    }
    
    override fun onTaskCompleted(context: Context, taskInfo: TaskDebugInfo, result: TaskResult) {
        // Your custom logic here
    }
}

// Set your custom handler
WorkmanagerDebug.setDebugHandler(CustomDebugHandler())
```

## iOS Debug Handlers

### 1. Logging Debug Handler (Recommended for Development)

Shows debug information in iOS's unified logging system (visible in Console.app and Xcode):

```swift
// In your AppDelegate.swift
import workmanager_apple

@main
class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Enable logging debug handler
        WorkmanagerDebug.setDebugHandler(LoggingDebugHandler())
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

### 2. Notification Debug Handler

Shows debug information as notifications (requires notification permissions):

```swift
// Enable notification debug handler
WorkmanagerDebug.setDebugHandler(NotificationDebugHandler())
```

### 3. Custom Debug Handler

Create your own debug handler by implementing `WorkmanagerDebugHandler`:

```swift
import workmanager_apple

class CustomDebugHandler: WorkmanagerDebugHandler {
    func onTaskStarting(taskInfo: TaskDebugInfo) {
        // Your custom logic here
    }
    
    func onTaskCompleted(taskInfo: TaskDebugInfo, result: TaskResult) {
        // Your custom logic here
    }
}

// Set your custom handler
WorkmanagerDebug.setDebugHandler(CustomDebugHandler())
```

## Disabling Debug Output

To disable all debug output (recommended for production):

```kotlin
// Android
WorkmanagerDebug.setDebugHandler(null)
```

```swift
// iOS
WorkmanagerDebug.setDebugHandler(nil)
```

## Benefits of the New System

1. **Flexibility**: Choose how debug information is handled
2. **Extensibility**: Create custom debug handlers for your needs
3. **Performance**: No overhead when disabled
4. **Platform Native**: Uses proper logging systems (Android Log, iOS os_log)
5. **Clean Separation**: Debug logic is separate from core functionality