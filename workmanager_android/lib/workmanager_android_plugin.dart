import 'workmanager_android.dart';

/// An implementation of [WorkmanagerAndroid] that uses method channels.
class WorkmanagerAndroidPlugin {
  /// Registers this class as the default instance of [WorkmanagerPlatform].
  static void registerWith() {
    WorkmanagerAndroid.registerWith();
  }
}
