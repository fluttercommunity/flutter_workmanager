# workmanager_ios

[![pub package](https://img.shields.io/pub/v/workmanager_ios.svg)](https://pub.dartlang.org/packages/workmanager_ios)

The iOS implementation of [`workmanager`][workmanager].

## Usage

This package is [endorsed][federated_plugin_docs], which means you can simply use `workmanager`
normally. This package will be automatically included in your app when you do,
so you do not need to add it to your `pubspec.yaml`.

However, if you `import` this plugin directly (instead of the generic `workmanager` plugin), 
you should add it to your `pubspec.yaml`:

```yaml
dependencies:
  workmanager_ios: ^0.8.0
```

## iOS setup

For iOS background processing, you need to configure your app properly. 
For detailed setup instructions, see the [iOS setup documentation][ios_setup].

## Features

This iOS implementation supports:

- **One-off tasks**: Execute background tasks once using BGTaskScheduler (iOS 13+)
- **Periodic tasks**: Execute background tasks using BGAppRefreshTask (iOS 13+) or Background Fetch
- **Processing tasks**: Execute long-running background tasks using BGProcessingTask (iOS 13+)
- **Task cancellation**: Cancel individual tasks or all tasks
- **Task constraints**: Network and charging requirements (iOS 13+)
- **Task scheduling info**: Print information about scheduled tasks (iOS 13+)

## Limitations

- **iOS 13+ required**: BGTaskScheduler features require iOS 13 or later
- **Tags not supported**: `cancelByTag` operations are not available on iOS
- **No scheduling status**: `isScheduledByUniqueName` is not supported on iOS
- **Background execution limits**: iOS strictly limits background execution time and frequency
- **System scheduling**: iOS determines when tasks actually run based on user behavior and system resources

## Background execution on iOS

Please note that iOS has strict limitations on background execution:

- Background tasks are scheduled by the system and may not run immediately
- The system considers user behavior patterns when scheduling background work
- Tasks may be throttled or denied if the app is used infrequently
- Background App Refresh must be enabled by the user for your app

For more information, see Apple's [Background Tasks documentation][apple_background_tasks].

[workmanager]: https://pub.dartlang.org/packages/workmanager
[federated_plugin_docs]: https://flutter.dev/go/federated-plugins
[ios_setup]: https://github.com/fluttercommunity/flutter_workmanager/blob/main/IOS_SETUP.md
[apple_background_tasks]: https://developer.apple.com/documentation/backgroundtasks