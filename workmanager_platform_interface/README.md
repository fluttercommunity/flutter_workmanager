# workmanager_platform_interface

[![pub package](https://img.shields.io/pub/v/workmanager_platform_interface.svg)](https://pub.dartlang.org/packages/workmanager_platform_interface)

A common platform interface for the [`workmanager`][workmanager] plugin.

This interface allows platform-specific implementations of the `workmanager`
plugin, as well as the plugin itself, to ensure they are supporting the
same interface.

## Usage

To implement a new platform-specific implementation of `workmanager`, extend
[`WorkmanagerPlatform`][platform_interface] with an implementation that performs the
platform-specific behavior, and when you register your plugin, set the default
`WorkmanagerPlatform` by calling
`WorkmanagerPlatform.instance = MyWorkmanagerPlatform()`.

## Note on breaking changes

Strongly prefer non-breaking changes (such as adding a method to the interface)
over breaking changes for this package.

See https://flutter.dev/go/platform-interface-breaking-changes for a discussion
on why a less-clean interface is preferable to a breaking change.

[workmanager]: https://pub.dartlang.org/packages/workmanager
[platform_interface]: lib/src/workmanager_platform_interface.dart