# Flutter Workmanager

[![pub package](https://img.shields.io/pub/v/workmanager.svg)](https://pub.dartlang.org/packages/workmanager)
[![pub points](https://img.shields.io/pub/points/workmanager)](https://pub.dev/packages/workmanager/score)
[![likes](https://img.shields.io/pub/likes/workmanager)](https://pub.dev/packages/workmanager/score)
[![popularity](https://img.shields.io/pub/popularity/workmanager)](https://pub.dev/packages/workmanager/score)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/fluttercommunity/flutter_workmanager/test.yml?branch=main&label=tests)](https://github.com/fluttercommunity/flutter_workmanager/actions)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/fluttercommunity/flutter_workmanager/blob/main/LICENSE)

Execute Dart code in the background, even when your app is closed. Perfect for data sync, file uploads, and periodic maintenance tasks.

## 📖 Full Documentation

**[Visit our comprehensive documentation →](https://docs.page/fluttercommunity/flutter_workmanager)**

## ⚡ Quick Start

### 1. Install
```yaml
dependencies:
  workmanager: ^0.8.0
```

### 2. Platform Setup
- **Android**: Works automatically ✅
- **iOS**: [5-minute setup required](https://docs.workmanager.dev/setup/ios) 

### 3. Initialize & Use
```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    print("Background task: $task");
    // Your background logic here
    return Future.value(true);
  });
}

void main() {
  Workmanager().initialize(callbackDispatcher);
  
  // Schedule a task
  Workmanager().registerPeriodicTask(
    "sync-task",
    "data-sync",
    frequency: Duration(hours: 1),
  );
  
  runApp(MyApp());
}
```

## 🎯 Common Use Cases

| Use Case | Documentation |
|----------|---------------|
| **Sync data from API** | [Data Sync Guide →](https://docs.page/fluttercommunity/flutter_workmanager/usecases/data-sync) |
| **Upload files in background** | [File Upload Guide →](https://docs.page/fluttercommunity/flutter_workmanager/usecases/upload-files) |
| **Clean up old data** | [Cleanup Guide →](https://docs.page/fluttercommunity/flutter_workmanager/usecases/periodic-cleanup) |
| **Fetch notifications** | [Notifications Guide →](https://docs.page/fluttercommunity/flutter_workmanager/usecases/fetch-notifications) |

## 🏗️ Architecture

This plugin uses a **federated architecture**:
- `workmanager` - Main package (this one)
- `workmanager_android` - Android implementation  
- `workmanager_apple` - iOS/macOS implementation
- `workmanager_platform_interface` - Shared interface

All packages are automatically included when you add `workmanager` to pubspec.yaml.

## 🐛 Issues & Support

- **Bug reports**: [GitHub Issues →](https://github.com/fluttercommunity/flutter_workmanager/issues)
- **Questions**: [GitHub Discussions →](https://github.com/fluttercommunity/flutter_workmanager/discussions)
- **Documentation**: [docs.page/fluttercommunity/flutter_workmanager →](https://docs.page/fluttercommunity/flutter_workmanager)

## 🚀 Example App

See the [example folder](./example/) for a complete working demo with all task types and platform configurations.