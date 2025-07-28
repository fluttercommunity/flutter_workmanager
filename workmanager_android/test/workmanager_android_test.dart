import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager_android/workmanager_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkmanagerAndroid', () {
    late WorkmanagerAndroid workmanager;

    setUp(() {
      workmanager = WorkmanagerAndroid();
    });

    group('registerProcessingTask', () {
      test('should throw UnsupportedError on Android', () async {
        expect(
          () => workmanager.registerProcessingTask(
              'processingTask', 'processingTaskName'),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('printScheduledTasks', () {
      test('should throw UnsupportedError on Android', () async {
        expect(
          () => workmanager.printScheduledTasks(),
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
