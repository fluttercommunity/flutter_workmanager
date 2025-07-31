import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';

const String dataTransferTaskName =
    'dev.fluttercommunity.integrationTest.dataTransferTask';
const String retryTaskName = 'dev.fluttercommunity.integrationTest.retryTask';

/// One retry is enough to test the retry logic
const int kMaxRetryAttempts = 1;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print(
        'CallbackDispatcher called with task: $task and inputData: $inputData');

    if (task == retryTaskName) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      var counterName = inputData!['counter_name'];
      final count = prefs.getInt(counterName) ?? 0;
      if (count == kMaxRetryAttempts) {
        return Future.value(true);
      } else {
        await prefs.setInt(counterName, count + 1);
        return Future.value(false);
      }
    }
    if (task == dataTransferTaskName) {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      for (String key in inputData!.keys) {
        var value = inputData[key];
        if (value is String) {
          await prefs.setString(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is List) {
          await prefs.setStringList(key, List<String>.from(value));
        } else if (value is Map) {
          await prefs.setString(key, value.toString());
        } else {
          print('Unsupported data type for key $key: $value');
        }
      }
    }
    return true;
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await SharedPreferences.getInstance().then((prefs) {
      return prefs.clear(); // Clear shared preferences before each test
    });
  });

  group('Workmanager Integration Tests', () {
    late Workmanager workmanager;

    setUp(() {
      workmanager = Workmanager();
    });

    testWidgets('initialize should succeed on all platforms',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);
      // No exception means success
    });

    testWidgets('input data is correctly transferred to native side',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      final prefix = Uuid().v4().toString();

      final testData = {
        '$prefix.string': 'input string',
        '$prefix.number': 42,
        '$prefix.boolean': true,
        '$prefix.list': ['1', '2', '3'],
        '$prefix.double': 3.14,
      };

      await workmanager.registerOneOffTask(
        dataTransferTaskName,
        dataTransferTaskName,
        inputData: testData,
      );

      // Look for 20 seconds & observe if the settings have been written
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(seconds: 1));
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        if (prefs.getString('$prefix.string') == 'input string' &&
            prefs.getInt('$prefix.number') == 42 &&
            prefs.getBool('$prefix.boolean') == true &&
            prefs.getStringList('$prefix.list')!.length == 3 &&
            prefs.getDouble('$prefix.double') == 3.14) {
          return;
        }
      }
      fail('Input data was not transferred correctly to native side.');
    });

    testWidgets('retry task should retry up to ${kMaxRetryAttempts} times',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      final counterName = Uuid().v4().toString() + 'retryCounter';
      final initialCount = 0;

      // Set initial count in shared preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(counterName, initialCount);

      try {
        await workmanager.registerOneOffTask(
          retryTaskName,
          retryTaskName,
          inputData: {'counter_name': counterName},
          backoffPolicy: BackoffPolicy.linear,
          backoffPolicyDelay: const Duration(seconds: 1),
        );

        // Wait for the task to complete
        for (int i = 0; i < 45; i++) {
          await Future.delayed(const Duration(seconds: 1));
          await prefs.reload();
          if (prefs.getInt(counterName) == kMaxRetryAttempts) {
            return;
          }
        }
        fail('Retry task did not reach maximum attempts.');
      } catch (e) {
        fail('Retry task failed with exception: $e');
      } finally {
        await workmanager.cancelByUniqueName(retryTaskName);
      }
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
            'list': ['1', '2', '3'],
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
          // Don't use outOfQuotaPolicy with non-supported constraints
        );
        // Clean up
        await workmanager.cancelByUniqueName('test.oneoff.full');
      }
    });

    testWidgets('registerOneOffTask with expedited job (Android)',
        (WidgetTester tester) async {
      await workmanager.initialize(callbackDispatcher);

      if (Platform.isAndroid) {
        // Expedited jobs only support network and storage constraints
        await workmanager.registerOneOffTask(
          'test.oneoff.expedited',
          'expeditedTask',
          inputData: {'expedited': 'true'},
          constraints: Constraints(
            networkType: NetworkType.connected,
            requiresStorageNotLow: true,
            // Can't use battery, charging, or idle constraints with expedited jobs
          ),
          existingWorkPolicy: ExistingWorkPolicy.replace,
          tag: 'expedited-tag',
          outOfQuotaPolicy: OutOfQuotaPolicy.runAsNonExpeditedWorkRequest,
        );
        // Clean up
        await workmanager.cancelByUniqueName('test.oneoff.expedited');
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
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
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
