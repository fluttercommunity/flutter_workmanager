import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  // Test callback dispatcher
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Backward compatibility', () {
    test('initialize() still accepts isInDebugMode parameter', () async {
      // This test verifies that existing code using isInDebugMode will still compile
      // The parameter is deprecated but should not break existing code
      //
      // Behavior differs by host: Linux now has a real implementation
      // (workmanager_linux) whose initialize is pure Dart — it succeeds
      // in-process without touching systemd. Windows still uses the
      // placeholder and throws UnimplementedError. On macOS/iOS/Android the
      // platform implementation is selected and the call fails with a channel
      // error because no plugin host is registered in the test environment.
      if (Platform.isLinux) {
        await Workmanager().initialize(
          callbackDispatcher,
          // ignore: deprecated_member_use_from_same_package
          isInDebugMode: true, // Deprecated but still compiles
        );
        await Workmanager().initialize(callbackDispatcher);
        return;
      }

      final expectedError = Platform.isWindows
          ? throwsA(isA<UnimplementedError>())
          : throwsA(anything);

      // This should compile without errors
      await expectLater(
        () async => await Workmanager().initialize(
          callbackDispatcher,
          // ignore: deprecated_member_use_from_same_package
          isInDebugMode: true, // Deprecated but still compiles
        ),
        expectedError,
      );

      // This should also compile (without the parameter)
      await expectLater(
        () async => await Workmanager().initialize(callbackDispatcher),
        expectedError,
      );
    });
  });
}
