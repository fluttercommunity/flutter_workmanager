# workmanager_apple

[![pub package](https://img.shields.io/pub/v/workmanager_apple.svg)](https://pub.dartlang.org/packages/workmanager_apple)
[![pub points](https://img.shields.io/pub/points/workmanager_apple)](https://pub.dev/packages/workmanager_apple/score)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/fluttercommunity/flutter_workmanager/blob/main/LICENSE)

The Apple platform (iOS/macOS) implementation of [`workmanager`][workmanager].

## Description

This package provides the Apple platform-specific implementation for the workmanager plugin, supporting iOS background fetch and BGTaskScheduler APIs for background task execution in Flutter applications on iOS and macOS.

## Usage

This package is [endorsed][federated_plugin_docs], which means you can simply use `workmanager`
normally. This package will be automatically included in your app when you do,
so you do not need to add it to your `pubspec.yaml`.

However, if you `import` this package directly, you should add it to your `pubspec.yaml`:

```yaml
dependencies:
  workmanager_apple: ^0.8.0
```

## Documentation

For detailed setup instructions, usage examples, and API documentation, please refer to the main [`workmanager`][workmanager] package documentation.

[workmanager]: https://pub.dartlang.org/packages/workmanager
[federated_plugin_docs]: https://flutter.dev/go/federated-plugins