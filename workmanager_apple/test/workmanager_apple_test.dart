import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager_apple/workmanager_apple.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkmanagerApple', () {
    late WorkmanagerApple workmanager;

    setUp(() {
      workmanager = WorkmanagerApple();
    });

    group('cancelByTag', () {
      test('should throw UnsupportedError on iOS', () async {
        expect(
          () => workmanager.cancelByTag('testTag'),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    // TODO: Add proper Pigeon-based tests for other methods
    // The old MethodChannel-based tests need to be rewritten to mock Pigeon APIs
    group('Pigeon API integration', () {
      test('should be skipped until proper mocking is implemented', () {
        // Skip tests that require Pigeon channel mocking
      }, skip: 'Pigeon API mocking needs to be implemented');
    });
  });
}
