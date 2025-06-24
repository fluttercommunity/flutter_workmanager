# workmanager_android

[![pub package](https://img.shields.io/pub/v/workmanager_android.svg)](https://pub.dartlang.org/packages/workmanager_android)

The Android implementation of [`workmanager`][workmanager].

## Usage

This package is [endorsed][federated_plugin_docs], which means you can simply use `workmanager`
normally. This package will be automatically included in your app when you do,
so you do not need to add it to your `pubspec.yaml`.

However, if you `import` this plugin directly (instead of the generic `workmanager` plugin), 
you should add it to your `pubspec.yaml`:

```yaml
dependencies:
  workmanager_android: ^0.8.0
```

## Android setup

Add the following to your `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Background processing permissions -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

For more detailed setup instructions, see the [Android setup documentation][android_setup].

## Features

This Android implementation supports:

- **One-off tasks**: Execute background tasks once after a delay
- **Periodic tasks**: Execute background tasks repeatedly at specified intervals
- **Task constraints**: Network, charging, battery, storage, and device idle requirements
- **Task cancellation**: Cancel individual tasks or all tasks
- **Work policies**: Configure what happens when tasks with the same unique name are registered
- **Backoff policies**: Configure retry behavior for failed tasks
- **Task scheduling info**: Check if periodic tasks are currently scheduled

## Limitations

- Processing tasks are not supported on Android (use one-off tasks instead)
- Tag-based operations work with individual tasks
- iOS-specific features like `printScheduledTasks` are not available

[workmanager]: https://pub.dartlang.org/packages/workmanager
[federated_plugin_docs]: https://flutter.dev/go/federated-plugins
[android_setup]: https://github.com/fluttercommunity/flutter_workmanager/blob/main/ANDROID_SETUP.md