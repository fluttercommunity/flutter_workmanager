import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import 'workmanager_ios.dart';

/// An implementation of [WorkmanagerIOS] that uses method channels.
class WorkmanagerIOSPlugin {
  /// Registers this class as the default instance of [WorkmanagerPlatform].
  static void registerWith() {
    WorkmanagerIOS.registerWith();
  }
}