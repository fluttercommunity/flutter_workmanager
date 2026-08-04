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

## Foreground service permissions

Expedited work runs as a `shortService` foreground service, so the plugin
always declares `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_SHORT_SERVICE`.

`FOREGROUND_SERVICE_DATA_SYNC` (the `dataSync` foreground service type, for
long-running workers) is **opt-in**: it is a Play Console "special type" that
requires a declaration form and a demonstration video even when unused, so it
is only added to your merged manifest when you enable it in your app's
`gradle.properties` (or pass it on the command line):

```properties
workmanager.enableDataSyncForegroundService=true
```

Only set this if your app actually runs long-running workers with the
`dataSync` foreground service type — see the `ForegroundServiceConfig` API
in the main package. See [issue #725](https://github.com/fluttercommunity/flutter_workmanager/issues/725).

[workmanager]: https://pub.dartlang.org/packages/workmanager
[federated_plugin_docs]: https://flutter.dev/go/federated-plugins