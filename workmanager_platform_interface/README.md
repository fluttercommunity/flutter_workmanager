# workmanager_platform_interface

[![pub package](https://img.shields.io/pub/v/workmanager_platform_interface.svg)](https://pub.dartlang.org/packages/workmanager_platform_interface)
[![pub points](https://img.shields.io/pub/points/workmanager_platform_interface)](https://pub.dev/packages/workmanager_platform_interface/score)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/fluttercommunity/flutter_workmanager/blob/main/LICENSE)

A common platform interface for the [`workmanager`][workmanager] plugin.

## Description

This package provides the common platform interface for the workmanager plugin, defining the API contract that platform-specific implementations must follow. It ensures consistency across different platform implementations.

## Usage

This interface is only relevant for packages that implement `workmanager` for a specific platform. App developers should use the main [`workmanager`][workmanager] package instead.

To implement a new platform-specific implementation of `workmanager`, extend
[`WorkmanagerPlatform`][platform_interface] with an implementation that performs the
platform-specific behavior, and when you register your plugin, set the default
`WorkmanagerPlatform` by calling
`WorkmanagerPlatform.instance = MyWorkmanagerPlatform()`.

## Note on Breaking Changes

Strongly prefer non-breaking changes (such as adding a method to the interface)
over breaking changes for this package.

See https://flutter.dev/go/platform-interface-breaking-changes for a discussion
on why a less-clean interface is preferable to a breaking change.

## Documentation

For detailed API documentation and usage examples, please refer to the main [`workmanager`][workmanager] package documentation.

[workmanager]: https://pub.dartlang.org/packages/workmanager
[platform_interface]: lib/src/workmanager_platform_interface.dart