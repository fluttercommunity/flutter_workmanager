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

## Documentation

For detailed setup instructions, usage examples, and platform-specific information, 
please refer to the main [`workmanager`][workmanager] package documentation.

[workmanager]: https://pub.dartlang.org/packages/workmanager
[federated_plugin_docs]: https://flutter.dev/go/federated-plugins