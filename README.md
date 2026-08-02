# Flutter Workmanager

[![pub package](https://img.shields.io/pub/v/workmanager.svg)](https://pub.dartlang.org/packages/workmanager)
[![pub points](https://img.shields.io/pub/points/workmanager)](https://pub.dev/packages/workmanager/score)
[![likes](https://img.shields.io/pub/likes/workmanager)](https://pub.dev/packages/workmanager/score)
[![popularity](https://img.shields.io/pub/popularity/workmanager)](https://pub.dev/packages/workmanager/score)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/fluttercommunity/flutter_workmanager/test.yml?branch=main&label=tests)](https://github.com/fluttercommunity/flutter_workmanager/actions)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/fluttercommunity/flutter_workmanager/blob/main/LICENSE)

Execute Dart code in the background, even when your app is closed (Android and iOS). On macOS, background tasks run while the app is running or backgrounded and the Mac is awake. Perfect for data sync, file uploads, and periodic maintenance tasks.

> ⚠️ **Experimental web support** now exists via `workmanager_web` (Service
> Worker + Web Worker based background execution). See the
> [Web (experimental)](docs/web.mdx) page and the
> [package README](workmanager_web/README.md) for honest limitations and how to
> test it in Chrome.

## 📖 Documentation

Get started with background tasks in Flutter:

**[→ Quick Start Guide](https://docs.page/fluttercommunity/flutter_workmanager/quickstart)** - Installation and setup

**[→ API Documentation](https://pub.dev/documentation/workmanager/latest/)** - Complete Dart API reference

**[→ Debugging Guide](https://docs.page/fluttercommunity/flutter_workmanager/debugging)** - Troubleshooting help

**[→ Troubleshooting Guide](https://docs.page/fluttercommunity/flutter_workmanager/troubleshooting)** - Why tasks stop after app close (OEM battery optimization, constraints, verification)

## 🎯 Use Cases

Background tasks are perfect for:
- **Sync data from API** - Keep your app's data fresh
- **Upload files in background** - Reliable file uploads
- **Clean up old data** - Remove old files and cache
- **Fetch notifications** - Check for new messages
- **Database maintenance** - Optimize and clean databases

## ⏱ Long-Running Tasks (Android)

For work that takes longer than the regular background execution window (bulk
uploads/downloads, ML processing), Android tasks can run as a **foreground
service** with a persistent notification. Pass a `foregroundServiceConfig` to
`registerOneOffTask` or `registerPeriodicTask`:

```dart
await Workmanager().registerOneOffTask(
  "upload-task",
  "upload_files",
  foregroundServiceConfig: ForegroundServiceConfig(
    notificationTitle: "Uploading files",
    notificationText: "Your files are being uploaded",
  ),
);
```

See the [Quick Start guide](https://docs.page/fluttercommunity/flutter_workmanager/quickstart)
for details and platform caveats.

## 🛑 Cancelling Running Work (Android)

`cancelByUniqueName`, `cancelByTag` and `cancelAll` stop the WorkManager worker
immediately, but the Dart callback that is currently running keeps executing
unless it reacts to the stop. Pass an `onTaskStopped` handler to `executeTask`
inside your `callbackDispatcher` to be notified when a running task is stopped
before it finishes:

```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask(
    (taskName, inputData) async {
      return true;
    },
    onTaskStopped: (taskName, stopReason) async {
      // Mark the task as cancelled / persist state, then return promptly.
    },
  );
}
```

The handler receives the task name and the WorkManager stop reason
(`cancelledByApp`, `timeout`, `preempt`, ...); on Android < 12 the reason is
`StopReason.unknown`. Android-only — iOS has no way to stop a running task.
See the [Customization guide](https://docs.page/fluttercommunity/flutter_workmanager/customization)
for details.


## 🐛 Issues & Support

- **Bug reports**: [GitHub Issues →](https://github.com/fluttercommunity/flutter_workmanager/issues)
- **Questions**: [GitHub Discussions →](https://github.com/fluttercommunity/flutter_workmanager/discussions)
- **Documentation**: [docs.page/fluttercommunity/flutter_workmanager →](https://docs.page/fluttercommunity/flutter_workmanager)

## 🚀 Example App

See the [example folder](./example/) for a complete working demo with all task types and platform configurations.
