import 'workmanager_apple.dart';

/// An implementation of [WorkmanagerApple] that uses method channels.
class WorkmanagerApplePlugin {
  /// Registers this class as the default instance of [WorkmanagerPlatform].
  static void registerWith() {
    WorkmanagerApple.registerWith();
  }
}
