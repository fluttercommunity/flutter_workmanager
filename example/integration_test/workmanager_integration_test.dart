import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return true;
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Workmanager Integration Tests', () {
    late Workmanager workmanager;

    setUp(() {
      workmanager = Workmanager();
    });

    testWidgets('initialize should succeed on all platforms',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher, isInDebugMode: true);
      // No exception means success
    });

    testWidgets('registerOneOffTask basic should succeed',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      try {
        await workmanager.registerOneOffTask(
          'test.oneoff.basic',
          'basicTask',
        );
        // Clean up
        await workmanager.cancelByUniqueName('test.oneoff.basic');
      } on PlatformException catch (e) {
        // iOS may fail with BGTaskSchedulerErrorDomain in testing environment
        if (Platform.isIOS && e.code.contains('bgTaskSchedulingFailed')) {
          // This is expected in test environment on iOS
        } else {
          rethrow;
        }
      }
    });

    testWidgets('registerOneOffTask with inputData should succeed',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      try {
        await workmanager.registerOneOffTask(
          'test.oneoff.data',
          'dataTask',
          inputData: {
            'string': 'test',
            'number': 42,
            'boolean': true,
            'list': [1, 2, 3],
            'map': {'nested': 'value'},
          },
        );
        // Clean up
        await workmanager.cancelByUniqueName('test.oneoff.data');
      } on PlatformException catch (e) {
        if (Platform.isIOS && e.code.contains('bgTaskSchedulingFailed')) {
          // Expected on iOS in test environment
        } else {
          rethrow;
        }
      }
    });

    testWidgets('registerOneOffTask with all parameters (Android)',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      if (Platform.isAndroid) {
        await workmanager.registerOneOffTask(
          'test.oneoff.full',
          'fullTask',
          inputData: {'test': 'data'},
          initialDelay: const Duration(seconds: 1),
          constraints: Constraints(
            networkType: NetworkType.connected,
            requiresBatteryNotLow: true,
            requiresCharging: false,
            requiresDeviceIdle: false,
            requiresStorageNotLow: true,
          ),
          existingWorkPolicy: ExistingWorkPolicy.replace,
          backoffPolicy: BackoffPolicy.exponential,
          backoffPolicyDelay: const Duration(seconds: 30),
          tag: 'test-tag',
          outOfQuotaPolicy: OutOfQuotaPolicy.dropWorkRequest,
        );
        // Clean up
        await workmanager.cancelByUniqueName('test.oneoff.full');
      }
    });

    testWidgets('registerPeriodicTask should work on supported platforms',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      try {
        await workmanager.registerPeriodicTask(
          'test.periodic.basic',
          'periodicTask',
          frequency: const Duration(minutes: 15),
        );
        // Clean up
        await workmanager.cancelByUniqueName('test.periodic.basic');
      } on PlatformException catch (e) {
        if (Platform.isIOS && e.code.contains('bgTaskSchedulingFailed')) {
          // Expected on iOS in test environment
        } else {
          rethrow;
        }
      }
    });

    testWidgets('registerPeriodicTask with parameters (Android)',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      if (Platform.isAndroid) {
        await workmanager.registerPeriodicTask(
          'test.periodic.full',
          'periodicFullTask',
          frequency: const Duration(minutes: 15),
          flexInterval: const Duration(minutes: 5),
          inputData: {'periodic': 'data'},
          initialDelay: const Duration(seconds: 1),
          constraints: Constraints(
            networkType: NetworkType.unmetered,
            requiresBatteryNotLow: false,
            requiresCharging: true,
          ),
          existingWorkPolicy: ExistingWorkPolicy.keep,
          backoffPolicy: BackoffPolicy.linear,
          backoffPolicyDelay: const Duration(seconds: 10),
          tag: 'periodic-tag',
        );
        // Clean up
        await workmanager.cancelByUniqueName('test.periodic.full');
      }
    });

    testWidgets('registerProcessingTask should work on iOS only',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      if (Platform.isIOS) {
        try {
          await workmanager.registerProcessingTask(
            'test.processing',
            'processingTask',
            initialDelay: const Duration(seconds: 1),
            inputData: {'processing': 'data'},
            constraints: Constraints(
              networkType: NetworkType.connected,
              requiresCharging: true,
            ),
          );
          // Clean up
          await workmanager.cancelByUniqueName('test.processing');
        } on PlatformException catch (e) {
          if (e.code.contains('bgTaskSchedulingFailed')) {
            // Expected in test environment
          } else {
            rethrow;
          }
        }
      } else {
        // Should throw UnsupportedError on Android
        expect(
          () => workmanager.registerProcessingTask(
            'test.processing',
            'processingTask',
          ),
          throwsA(isA<UnsupportedError>()),
        );
      }
    });

    testWidgets('cancelByUniqueName should succeed',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      // Should not throw even if task doesn't exist
      await workmanager.cancelByUniqueName('nonexistent.task');
    });

    testWidgets('cancelByTag should work on Android only',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      if (Platform.isAndroid) {
        // Should not throw even if no tasks with tag exist
        await workmanager.cancelByTag('nonexistent-tag');
      } else {
        // Should throw UnsupportedError on iOS
        expect(
          () => workmanager.cancelByTag('test-tag'),
          throwsA(isA<UnsupportedError>()),
        );
      }
    });

    testWidgets('cancelAll should succeed', (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      try {
        await workmanager.cancelAll();
      } on PlatformException catch (e) {
        if (Platform.isIOS && e.code.contains('bgTaskSchedulingFailed')) {
          // Expected on iOS in some test environments
        } else {
          rethrow;
        }
      }
    });

    testWidgets('isScheduled should work on Android only',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      if (Platform.isAndroid) {
        // Test with a task that doesn't exist
        final isScheduled =
            await workmanager.isScheduledByUniqueName('nonexistent.task');
        expect(isScheduled, false);

        // Register a task and check if it's scheduled
        try {
          await workmanager.registerOneOffTask(
            'test.scheduled',
            'scheduledTask',
          );
          final isScheduledAfterRegister =
              await workmanager.isScheduledByUniqueName('test.scheduled');
          expect(isScheduledAfterRegister, true);

          // Clean up
          await workmanager.cancelByUniqueName('test.scheduled');

          // Check again after cancellation
          final isScheduledAfterCancel =
              await workmanager.isScheduledByUniqueName('test.scheduled');
          expect(isScheduledAfterCancel, false);
        } catch (e) {
          // Clean up even if test fails
          await workmanager.cancelByUniqueName('test.scheduled');
          rethrow;
        }
      } else {
        // Should throw UnsupportedError on iOS
        expect(
          () => workmanager.isScheduledByUniqueName('test-task'),
          throwsA(isA<UnsupportedError>()),
        );
      }
    });

    testWidgets('printScheduledTasks should work on iOS only',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      if (Platform.isIOS) {
        final result = await workmanager.printScheduledTasks();
        expect(result, isA<String>());
      } else {
        // Should throw UnsupportedError on Android
        expect(
          () => workmanager.printScheduledTasks(),
          throwsA(isA<UnsupportedError>()),
        );
      }
    });

    testWidgets('multiple task registration and cancellation flow',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      final taskIds = ['test.multi.1', 'test.multi.2', 'test.multi.3'];

      try {
        // Register multiple tasks
        for (int i = 0; i < taskIds.length; i++) {
          await workmanager.registerOneOffTask(
            taskIds[i],
            'multiTask$i',
            inputData: {'index': i},
          );
        }

        // Cancel individual tasks
        await workmanager.cancelByUniqueName(taskIds[0]);

        if (Platform.isAndroid) {
          // Verify first task is cancelled, others remain
          expect(await workmanager.isScheduledByUniqueName(taskIds[0]), false);
          expect(await workmanager.isScheduledByUniqueName(taskIds[1]), true);
          expect(await workmanager.isScheduledByUniqueName(taskIds[2]), true);
        }

        // Cancel all remaining tasks
        await workmanager.cancelAll();

        if (Platform.isAndroid) {
          // Verify all tasks are cancelled
          for (final taskId in taskIds) {
            expect(await workmanager.isScheduledByUniqueName(taskId), false);
          }
        }
      } on PlatformException catch (e) {
        if (Platform.isIOS && e.code.contains('bgTaskSchedulingFailed')) {
          // Expected on iOS in test environment
        } else {
          rethrow;
        }
      } finally {
        // Ensure cleanup
        await workmanager.cancelAll();
      }
    });
  });
}
