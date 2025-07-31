# Flutter Workmanager

[![pub package](https://img.shields.io/pub/v/workmanager.svg)](https://pub.dartlang.org/packages/workmanager)
[![pub points](https://img.shields.io/pub/points/workmanager)](https://pub.dev/packages/workmanager/score)
[![likes](https://img.shields.io/pub/likes/workmanager)](https://pub.dev/packages/workmanager/score)
[![popularity](https://img.shields.io/pub/popularity/workmanager)](https://pub.dev/packages/workmanager/score)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/fluttercommunity/flutter_workmanager/test.yml?branch=main&label=tests)](https://github.com/fluttercommunity/flutter_workmanager/actions)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/fluttercommunity/flutter_workmanager/blob/main/LICENSE)

Execute Dart code in the background, even when your app is closed. A Flutter wrapper around [Android's WorkManager](https://developer.android.com/topic/libraries/architecture/workmanager) and [iOS Background Tasks](https://developer.apple.com/documentation/backgroundtasks).

## 📖 Documentation

**[Complete documentation is available at docs.page →](https://docs.page/fluttercommunity/flutter_workmanager)**

- **[Quick Start Guide](https://docs.page/fluttercommunity/flutter_workmanager/quickstart)** - Installation and platform setup
- **[API Documentation](https://pub.dev/documentation/workmanager/latest/)** - Complete Dart API reference  
- **[Debugging Guide](https://docs.page/fluttercommunity/flutter_workmanager/debugging)** - Troubleshooting and debug hooks

## 🚀 Quick Example

```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Background task: $task");
    // Your background work here
    return Future.value(true);
  });
}

void main() {
  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerOneOffTask("task-id", "simpleTask");
  runApp(MyApp());
}
```

## 🎯 Use Cases

Perfect for:
- **Data sync** - Keep your app's data fresh
- **File uploads** - Reliable uploads in background  
- **Cleanup tasks** - Remove old files and cache
- **Notifications** - Check for new messages
- **Database maintenance** - Optimize and clean databases

## 🏗️ Federated Architecture

This plugin uses a federated architecture with platform-specific implementations:

- **workmanager**: Main package providing the unified API
- **workmanager_android**: Android implementation using WorkManager
- **workmanager_apple**: iOS/macOS implementation using Background Tasks

## 🐛 Support & Issues

- **Documentation**: [docs.page/fluttercommunity/flutter_workmanager](https://docs.page/fluttercommunity/flutter_workmanager)
- **Bug Reports**: [GitHub Issues](https://github.com/fluttercommunity/flutter_workmanager/issues)
- **Questions**: [GitHub Discussions](https://github.com/fluttercommunity/flutter_workmanager/discussions)

## 📱 Example App

See the [example folder](../example/) for a complete working demo with all features.

---

For detailed setup instructions, advanced configuration, and troubleshooting, visit the **[complete documentation](https://docs.page/fluttercommunity/flutter_workmanager)**.