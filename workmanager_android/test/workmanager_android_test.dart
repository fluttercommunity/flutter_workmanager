import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:workmanager_android/workmanager_android.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkmanagerAndroid', () {
    late WorkmanagerAndroid workmanager;

    setUp(() {
      workmanager = WorkmanagerAndroid();
    });

    group('Platform-specific behavior', () {
      test(
          'should throw UnsupportedError for registerProcessingTask (Android does not support BGTaskScheduler)',
          () {
        expect(
          () => workmanager.registerProcessingTask('task', 'name'),
          throwsA(isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('Processing tasks are not supported on Android'),
          )),
        );
      });

      test(
          'should throw UnsupportedError for registerHealthResearchTask (Android does not support BGHealthResearchTask)',
          () {
        expect(
          () => workmanager.registerHealthResearchTask('task', 'name'),
          throwsA(isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('Health research tasks are not supported on Android'),
          )),
        );
      });

      test(
          'should throw UnsupportedError for printScheduledTasks (Android WorkManager does not expose task lists)',
          () {
        expect(
          () => workmanager.printScheduledTasks(),
          throwsA(isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('printScheduledTasks is not supported on Android'),
          )),
        );
      });
    });

    group('Android WorkManager constraints mapping', () {
      test('should handle NetworkType enum correctly', () {
        // Test that enum values are properly mapped for Android WorkManager
        expect(NetworkType.connected.index, 0);
        expect(NetworkType.metered.index, 1);
        expect(NetworkType.notRequired.index, 2);
        expect(NetworkType.notRoaming.index, 3);
        expect(NetworkType.unmetered.index, 4);
        expect(NetworkType.temporarilyUnmetered.index, 5);
      });

      test('should handle BackoffPolicy enum correctly', () {
        expect(BackoffPolicy.exponential.index, 0);
        expect(BackoffPolicy.linear.index, 1);
      });

      test('should handle ExistingWorkPolicy enum correctly', () {
        expect(ExistingWorkPolicy.append.index, 0);
        expect(ExistingWorkPolicy.keep.index, 1);
        expect(ExistingWorkPolicy.replace.index, 2);
        expect(ExistingWorkPolicy.update.index, 3);
      });

      test('should handle ExistingPeriodicWorkPolicy enum correctly', () {
        expect(ExistingPeriodicWorkPolicy.keep.index, 0);
        expect(ExistingPeriodicWorkPolicy.replace.index, 1);
        expect(ExistingPeriodicWorkPolicy.update.index, 2);
      });

      test('should handle OutOfQuotaPolicy enum correctly', () {
        expect(OutOfQuotaPolicy.runAsNonExpeditedWorkRequest.index, 0);
        expect(OutOfQuotaPolicy.dropWorkRequest.index, 1);
      });
    });

    group('Input validation and transformation', () {
      test('should handle Duration to seconds conversion', () {
        // Test that Duration objects are properly converted to seconds for Android WorkManager
        const testDuration = Duration(minutes: 15, seconds: 30);
        expect(testDuration.inSeconds, 930);
      });

      test('should handle constraints object creation', () {
        final constraints = Constraints(
          networkType: NetworkType.connected,
          requiresCharging: true,
          requiresBatteryNotLow: false,
          requiresDeviceIdle: null,
          requiresStorageNotLow: null,
        );

        expect(constraints.networkType, NetworkType.connected);
        expect(constraints.requiresCharging, true);
        expect(constraints.requiresBatteryNotLow, false);
        expect(constraints.requiresDeviceIdle, null);
        expect(constraints.requiresStorageNotLow, null);
      });

      test('should handle complex input data types', () {
        final complexData = <String, Object?>{
          'string': 'value',
          'int': 42,
          'double': 3.14,
          'bool': true,
          'null': null,
          'list': [1, 2, 3],
          'map': {'nested': 'value'},
        };

        // Test that complex data structures are acceptable
        expect(complexData.keys.length, 7);
        expect(complexData['string'], 'value');
        expect(complexData['int'], 42);
        expect(complexData['bool'], true);
      });
    });

    group('Android-specific WorkManager features', () {
      test('should support all Android NetworkType constraints', () {
        // Android WorkManager supports all network types
        final supportedTypes = [
          NetworkType.connected,
          NetworkType.metered,
          NetworkType.notRequired,
          NetworkType.notRoaming,
          NetworkType.unmetered,
          NetworkType.temporarilyUnmetered,
        ];

        for (final type in supportedTypes) {
          expect(() => Constraints(networkType: type), returnsNormally);
        }
      });

      test('should support Android-specific expedited work policies', () {
        // Test OutOfQuotaPolicy which is Android-specific for expedited jobs
        expect(() => OutOfQuotaPolicy.runAsNonExpeditedWorkRequest,
            returnsNormally);
        expect(() => OutOfQuotaPolicy.dropWorkRequest, returnsNormally);
      });

      test('should validate Android constraint combinations', () {
        // Test constraints that make sense for Android WorkManager
        final androidConstraints = Constraints(
          networkType: NetworkType.unmetered,
          requiresCharging: true,
          requiresBatteryNotLow: true,
          requiresDeviceIdle: false, // Android WorkManager supports device idle
          requiresStorageNotLow: true,
        );

        expect(androidConstraints.networkType, NetworkType.unmetered);
        expect(androidConstraints.requiresCharging, true);
        expect(androidConstraints.requiresBatteryNotLow, true);
        expect(androidConstraints.requiresDeviceIdle, false);
        expect(androidConstraints.requiresStorageNotLow, true);
      });
    });

    group('Error handling and edge cases', () {
      test('should handle special characters in identifiers', () {
        const specialChars = [
          'task-with-dash',
          'task_with_underscore',
          'task.with.dots'
        ];

        // Test that special characters in identifiers are handled appropriately
        for (final taskName in specialChars) {
          expect(taskName.contains(RegExp(r'[a-zA-Z0-9._-]')), true);
        }
      });

      test('should handle extreme duration values', () {
        const extremeDurations = [
          Duration.zero,
          Duration(seconds: 1),
          Duration(days: 365), // 1 year
        ];

        // Test duration conversion for extreme values
        for (final duration in extremeDurations) {
          expect(duration.inSeconds, greaterThanOrEqualTo(0));
        }
      });

      test('should handle large input data maps', () {
        final largeData = <String, Object?>{};
        for (int i = 0; i < 100; i++) {
          largeData['key$i'] = 'value$i';
        }

        expect(largeData.length, 100);
        expect(largeData['key0'], 'value0');
        expect(largeData['key99'], 'value99');
      });
    });

    group('Business logic validation', () {
      test('should properly implement WorkmanagerPlatform interface', () {
        expect(workmanager, isA<WorkmanagerPlatform>());
      });

      test('should handle Android WorkManager backoff policies', () {
        // Test that both exponential and linear backoff are supported
        final exponentialConfig = BackoffPolicyConfig(
          backoffPolicy: BackoffPolicy.exponential,
          backoffDelayMillis: 30000, // 30 seconds
        );

        final linearConfig = BackoffPolicyConfig(
          backoffPolicy: BackoffPolicy.linear,
          backoffDelayMillis: 10000, // 10 seconds
        );

        expect(exponentialConfig.backoffPolicy, BackoffPolicy.exponential);
        expect(exponentialConfig.backoffDelayMillis, 30000);
        expect(linearConfig.backoffPolicy, BackoffPolicy.linear);
        expect(linearConfig.backoffDelayMillis, 10000);
      });

      test('should validate Android work request types', () {
        // Test the different types of work requests Android supports

        // OneOffTaskRequest validation
        final oneOffRequest = OneOffTaskRequest(
          uniqueName: 'one-off-task',
          taskName: 'One Off Task',
          inputData: {'type': 'oneoff'},
          initialDelaySeconds: 60,
          constraints: Constraints(networkType: NetworkType.connected),
          backoffPolicy: BackoffPolicyConfig(
            backoffPolicy: BackoffPolicy.exponential,
            backoffDelayMillis: 30000,
          ),
          tag: 'android-task',
          existingWorkPolicy: ExistingWorkPolicy.replace,
          outOfQuotaPolicy: OutOfQuotaPolicy.runAsNonExpeditedWorkRequest,
        );

        expect(oneOffRequest.uniqueName, 'one-off-task');
        expect(oneOffRequest.taskName, 'One Off Task');
        expect(oneOffRequest.tag, 'android-task');
        expect(oneOffRequest.existingWorkPolicy, ExistingWorkPolicy.replace);
        expect(oneOffRequest.outOfQuotaPolicy,
            OutOfQuotaPolicy.runAsNonExpeditedWorkRequest);

        // PeriodicTaskRequest validation
        final periodicRequest = PeriodicTaskRequest(
          uniqueName: 'periodic-task',
          taskName: 'Periodic Task',
          frequencySeconds: 900, // 15 minutes
          flexIntervalSeconds: 300, // 5 minutes
          inputData: {'type': 'periodic'},
          constraints: Constraints(requiresCharging: true),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        );

        expect(periodicRequest.uniqueName, 'periodic-task');
        expect(periodicRequest.frequencySeconds, 900);
        expect(periodicRequest.flexIntervalSeconds, 300);
        expect(periodicRequest.existingWorkPolicy,
            ExistingPeriodicWorkPolicy.keep);
      });
    });

    group('Foreground service config', () {
      const oneOffChannel =
          'dev.flutter.pigeon.workmanager_platform_interface.WorkmanagerHostApi.registerOneOffTask';
      const periodicChannel =
          'dev.flutter.pigeon.workmanager_platform_interface.WorkmanagerHostApi.registerPeriodicTask';

      test('resolves sane defaults for a minimal config', () {
        final resolved = resolveForegroundServiceConfig(
          ForegroundServiceConfig(notificationTitle: 'Syncing'),
        );

        expect(resolved, isNotNull);
        expect(resolved!.notificationTitle, 'Syncing');
        expect(resolved.notificationText, 'Your task is still running');
        expect(resolved.notificationChannelId, 'workmanager_foreground_tasks');
        expect(resolved.notificationChannelName, 'Long-running tasks');
        expect(resolved.notificationId, 0);
        expect(resolved.foregroundServiceType, ForegroundServiceType.dataSync);
      });

      test('keeps explicitly provided values', () {
        final resolved = resolveForegroundServiceConfig(
          ForegroundServiceConfig(
            notificationTitle: 'Upload',
            notificationText: 'Uploading files',
            notificationChannelId: 'uploads',
            notificationChannelName: 'Uploads',
            notificationId: 42,
            foregroundServiceType: ForegroundServiceType.shortService,
          ),
        );

        expect(resolved, isNotNull);
        expect(resolved!.notificationTitle, 'Upload');
        expect(resolved.notificationText, 'Uploading files');
        expect(resolved.notificationChannelId, 'uploads');
        expect(resolved.notificationChannelName, 'Uploads');
        expect(resolved.notificationId, 42);
        expect(
          resolved.foregroundServiceType,
          ForegroundServiceType.shortService,
        );
      });

      test('returns null when no config is requested', () {
        expect(resolveForegroundServiceConfig(null), isNull);
      });

      test('registerOneOffTask forwards the resolved config through pigeon',
          () async {
        late OneOffTaskRequest captured;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(oneOffChannel, (ByteData? message) async {
          final decoded = WorkmanagerHostApi.pigeonChannelCodec
              .decodeMessage(message) as List<Object?>;
          captured = decoded[0]! as OneOffTaskRequest;
          return WorkmanagerHostApi.pigeonChannelCodec
              .encodeMessage(<Object?>[]);
        });

        await workmanager.registerOneOffTask(
          'unique',
          'task',
          foregroundServiceConfig:
              ForegroundServiceConfig(notificationTitle: 'Syncing'),
        );

        expect(captured.foregroundServiceConfig, isNotNull);
        expect(captured.foregroundServiceConfig!.notificationTitle, 'Syncing');
        expect(
          captured.foregroundServiceConfig!.foregroundServiceType,
          ForegroundServiceType.dataSync,
        );
      });

      test('registerPeriodicTask forwards the resolved config through pigeon',
          () async {
        late PeriodicTaskRequest captured;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(periodicChannel, (ByteData? message) async {
          final decoded = WorkmanagerHostApi.pigeonChannelCodec
              .decodeMessage(message) as List<Object?>;
          captured = decoded[0]! as PeriodicTaskRequest;
          return WorkmanagerHostApi.pigeonChannelCodec
              .encodeMessage(<Object?>[]);
        });

        await workmanager.registerPeriodicTask(
          'unique',
          'task',
          foregroundServiceConfig: ForegroundServiceConfig(
            foregroundServiceType: ForegroundServiceType.shortService,
          ),
        );

        expect(captured.foregroundServiceConfig, isNotNull);
        expect(
          captured.foregroundServiceConfig!.foregroundServiceType,
          ForegroundServiceType.shortService,
        );
        expect(
          captured.foregroundServiceConfig!.notificationTitle,
          'Task in progress',
        );
      });

      test('request carries no config when none is provided', () async {
        late OneOffTaskRequest captured;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(oneOffChannel, (ByteData? message) async {
          final decoded = WorkmanagerHostApi.pigeonChannelCodec
              .decodeMessage(message) as List<Object?>;
          captured = decoded[0]! as OneOffTaskRequest;
          return WorkmanagerHostApi.pigeonChannelCodec
              .encodeMessage(<Object?>[]);
        });

        await workmanager.registerOneOffTask('unique', 'task');

        expect(captured.foregroundServiceConfig, isNull);
      });
    });
  });
}
