# workmanager_android

[![pub package](https://img.shields.io/pub/v/workmanager_android.svg)](https://pub.dartlang.org/packages/workmanager_android)
[![pub points](https://img.shields.io/pub/points/workmanager_android)](https://pub.dev/packages/workmanager_android/score)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/fluttercommunity/flutter_workmanager/blob/main/LICENSE)

The Android implementation of [`workmanager`][workmanager].

## Description

This package provides the Android-specific implementation for the workmanager plugin, wrapping Android's WorkManager API to enable background task execution in Flutter applications.

## Usage

This package is [endorsed][federated_plugin_docs], which means you can simply use `workmanager`
normally. This package will be automatically included in your app when you do,
so you do not need to add it to your `pubspec.yaml`.

However, if you `import` this package directly, you should add it to your `pubspec.yaml`:

```yaml
dependencies:
  workmanager_android: ^0.8.0
```

## Documentation

For detailed setup instructions, usage examples, and API documentation, please refer to the main [`workmanager`][workmanager] package documentation.

[workmanager]: https://pub.dartlang.org/packages/workmanager
[federated_plugin_docs]: https://flutter.dev/go/federated-plugins