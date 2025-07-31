import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  // Test callback dispatcher
}

void main() {
  group('Backward compatibility', () {
    test('initialize() still accepts isInDebugMode parameter', () async {
      // This test verifies that existing code using isInDebugMode will still compile
      // The parameter is deprecated but should not break existing code

      // This should compile without errors
      await expectLater(
        () async => await Workmanager().initialize(
          callbackDispatcher,
          // ignore: deprecated_member_use_from_same_package
          isInDebugMode: true, // Deprecated but still compiles
        ),
        throwsA(isA<UnimplementedError>()), // Platform not available in tests
      );

      // This should also compile (without the parameter)
      await expectLater(
        () async => await Workmanager().initialize(callbackDispatcher),
        throwsA(isA<UnimplementedError>()), // Platform not available in tests
      );
    });
  });
}
