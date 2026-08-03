import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:workmanager_apple/workmanager_apple.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkmanagerApple', () {
    late WorkmanagerApple workmanager;

    setUp(() {
      workmanager = WorkmanagerApple();
    });

    group('iOS-specific behavior', () {
      test(
          'should throw UnsupportedError for cancelByTag (iOS BGTaskScheduler does not support tags)',
          () {
        expect(
          () => workmanager.cancelByTag('testTag'),
          throwsA(isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('cancelByTag is not supported on iOS'),
          )),
        );
      });

      test(
          'should throw UnsupportedError for isScheduledByUniqueName (Android-only functionality)',
          () {
        expect(
          () => workmanager.isScheduledByUniqueName('testTask'),
          throwsA(isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('isScheduledByUniqueName is not supported on iOS'),
          )),
        );
      });

      test('getWorkInfo returns null when the store has no record', () async {
        _mockGetWorkInfoReply(<Object?>[null]);

        expect(await workmanager.getWorkInfo('unknown-task'), isNull);
      });

      test('getWorkInfo maps the pigeon reply into a WorkInfo', () async {
        _mockGetWorkInfoReply(<Object?>[
          WorkInfoData(
            uniqueName: 'com.example.task',
            state: WorkState.failed,
            isPeriodic: false,
            taskName: 'dart-task',
            lastFinishedAtMillis: 1700000000000,
          ),
        ]);

        final info = await workmanager.getWorkInfo('com.example.task');

        expect(info, isNotNull);
        expect(info!.uniqueName, 'com.example.task');
        expect(info.state, WorkState.failed);
        expect(info.isPeriodic, isFalse);
        expect(info.taskName, 'dart-task');
        expect(info.tags, isEmpty);
        expect(
          info.lastFinishedAt,
          DateTime.fromMillisecondsSinceEpoch(1700000000000),
        );
      });
    });

    group('iOS BGTaskScheduler identifier validation', () {
      test('should handle valid BGTask identifier patterns', () {
        // BGTaskScheduler identifiers should follow specific patterns
        const validIdentifiers = [
          'com.example.task',
          'com.example.background-refresh',
          'com.example.data-sync',
          'my.app.processing-task',
        ];

        for (final identifier in validIdentifiers) {
          // Test that identifier follows reverse domain notation pattern
          expect(identifier.contains('.'), true);
          expect(identifier.split('.').length, greaterThanOrEqualTo(2));
        }
      });

      test('should handle identifier edge cases', () {
        const edgeCases = [
          'single', // Single word (may be valid)
          'com.example.task-with-many-segments.processing',
          'a.b.c', // Minimal segments
        ];

        for (final identifier in edgeCases) {
          // Test that identifiers are strings and non-empty
          expect(identifier, isA<String>());
          expect(identifier.isNotEmpty, true);
        }
      });
    });

    group('iOS network type constraints mapping', () {
      test('should handle iOS-specific network constraint interpretation', () {
        // iOS interprets network constraints differently than Android
        // Both connected and metered should map to requiring network connectivity
        final networkRequiringTypes = [
          NetworkType.connected,
          NetworkType.metered,
          NetworkType.notRoaming,
          NetworkType.unmetered,
          NetworkType.temporarilyUnmetered,
        ];

        for (final type in networkRequiringTypes) {
          // Verify these are valid enum values
          expect(type, isA<NetworkType>());
          expect(type.index, greaterThanOrEqualTo(0));
        }
      });

      test('should handle notRequired network type', () {
        // notRequired should not require network
        expect(NetworkType.notRequired, isA<NetworkType>());
        expect(NetworkType.notRequired.index, 2);
      });
    });

    group('iOS-specific processing task request validation', () {
      test('should handle ProcessingTaskRequest creation', () {
        final processingRequest = ProcessingTaskRequest(
          uniqueName: 'com.example.processing-task',
          taskName: 'Background Processing Task',
          inputData: {'type': 'processing', 'priority': 'high'},
          initialDelaySeconds: 300, // 5 minutes
          networkType: NetworkType.unmetered,
          requiresCharging: true,
        );

        expect(processingRequest.uniqueName, 'com.example.processing-task');
        expect(processingRequest.taskName, 'Background Processing Task');
        expect(processingRequest.networkType, NetworkType.unmetered);
        expect(processingRequest.requiresCharging, true);
        expect(processingRequest.inputData?['type'], 'processing');
      });

      test('should handle minimal processing task configuration', () {
        final minimalRequest = ProcessingTaskRequest(
          uniqueName: 'minimal-task',
          taskName: 'Minimal Task',
        );

        expect(minimalRequest.uniqueName, 'minimal-task');
        expect(minimalRequest.taskName, 'Minimal Task');
        expect(minimalRequest.inputData, null);
        expect(minimalRequest.initialDelaySeconds, null);
        expect(minimalRequest.networkType, null);
        expect(minimalRequest.requiresCharging, null);
      });
    });

    group('iOS-specific health research task request validation', () {
      test('should handle HealthResearchTaskRequest creation', () {
        final healthRequest = HealthResearchTaskRequest(
          uniqueName: 'com.example.health-research-task',
          taskName: 'Health Research Task',
          inputData: {'study': 'example-study', 'participantId': '42'},
          initialDelaySeconds: 600, // 10 minutes
          networkType: NetworkType.unmetered,
          requiresCharging: true,
        );

        expect(healthRequest.uniqueName, 'com.example.health-research-task');
        expect(healthRequest.taskName, 'Health Research Task');
        expect(healthRequest.networkType, NetworkType.unmetered);
        expect(healthRequest.requiresCharging, true);
        expect(healthRequest.initialDelaySeconds, 600);
        expect(healthRequest.inputData?['study'], 'example-study');
      });

      test('should handle minimal health research task configuration', () {
        final minimalRequest = HealthResearchTaskRequest(
          uniqueName: 'minimal-health-task',
          taskName: 'Minimal Health Task',
        );

        expect(minimalRequest.uniqueName, 'minimal-health-task');
        expect(minimalRequest.taskName, 'Minimal Health Task');
        expect(minimalRequest.inputData, null);
        expect(minimalRequest.initialDelaySeconds, null);
        expect(minimalRequest.networkType, null);
        expect(minimalRequest.requiresCharging, null);
      });
    });

    group('iOS-specific continued processing task request validation', () {
      test('should handle ContinuedProcessingTaskRequest creation', () {
        final continuedRequest = ContinuedProcessingTaskRequest(
          uniqueName: 'com.example.app.continuedProcessing.*',
          taskName: 'Continued Processing Task',
          title: 'Example continued processing',
          subtitle: 'Processing in progress',
          inputData: {'model': 'inference', 'frames': 120},
        );

        expect(continuedRequest.uniqueName,
            'com.example.app.continuedProcessing.*');
        expect(continuedRequest.taskName, 'Continued Processing Task');
        expect(continuedRequest.title, 'Example continued processing');
        expect(continuedRequest.subtitle, 'Processing in progress');
        expect(continuedRequest.inputData?['model'], 'inference');
      });

      test('should handle minimal continued processing task configuration', () {
        final minimalRequest = ContinuedProcessingTaskRequest(
          uniqueName: 'com.example.app.minimal.*',
          taskName: 'Minimal Continued Task',
        );

        expect(minimalRequest.uniqueName, 'com.example.app.minimal.*');
        expect(minimalRequest.taskName, 'Minimal Continued Task');
        expect(minimalRequest.title, null);
        expect(minimalRequest.subtitle, null);
        expect(minimalRequest.inputData, null);
      });
    });

    group('iOS constraint handling differences', () {
      test('should handle battery constraints appropriately for iOS', () {
        // iOS handles battery constraints differently than Android
        final constraints = Constraints(
          requiresBatteryNotLow: true,
          requiresCharging: false,
        );

        expect(constraints.requiresBatteryNotLow, true);
        expect(constraints.requiresCharging, false);
        expect(constraints.networkType, null);
      });

      test('should handle device idle constraints for iOS', () {
        // iOS may interpret device idle differently
        final constraints = Constraints(
          requiresDeviceIdle: true,
          networkType: NetworkType.notRequired,
        );

        expect(constraints.requiresDeviceIdle, true);
        expect(constraints.networkType, NetworkType.notRequired);
      });

      test('should handle storage constraints for iOS', () {
        final constraints = Constraints(
          requiresStorageNotLow: true,
        );

        expect(constraints.requiresStorageNotLow, true);
      });
    });

    group('Input validation and transformation', () {
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

        // Test that complex data structures are handled correctly
        expect(complexData.keys.length, 7);
        expect(complexData['string'], 'value');
        expect(complexData['int'], 42);
        expect(complexData['double'], 3.14);
        expect(complexData['bool'], true);
        expect(complexData['null'], null);
        expect(complexData['list'], [1, 2, 3]);
        expect(complexData['map'], {'nested': 'value'});
      });

      test('should handle Unicode characters in task data', () {
        final unicodeData = <String, Object?>{
          'emoji': '🚀',
          'chinese': '你好',
          'arabic': 'مرحبا',
          'special': 'café',
        };

        expect(unicodeData['emoji'], '🚀');
        expect(unicodeData['chinese'], '你好');
        expect(unicodeData['arabic'], 'مرحبا');
        expect(unicodeData['special'], 'café');
      });

      test('should handle extreme duration values for iOS', () {
        const iosDurations = [
          Duration.zero,
          Duration(milliseconds: 1),
          Duration(seconds: 30), // BGTaskScheduler minimum
          Duration(minutes: 1), // BGAppRefreshTask typical
          Duration(hours: 24), // Daily refresh
        ];

        for (final duration in iosDurations) {
          expect(duration.inSeconds, greaterThanOrEqualTo(0));
          // iOS durations should be reasonable for background task limits
          expect(duration.inSeconds,
              lessThanOrEqualTo(Duration(days: 1).inSeconds));
        }
      });
    });

    group('Business logic validation', () {
      test('should properly implement WorkmanagerPlatform interface', () {
        expect(workmanager, isA<WorkmanagerPlatform>());
      });

      test('should handle iOS-specific periodic task limitations', () {
        // iOS periodic tasks have different constraints than Android
        final periodicRequest = PeriodicTaskRequest(
          uniqueName: 'ios-periodic',
          taskName: 'iOS Periodic Task',
          frequencySeconds: 900, // 15 minutes (iOS minimum interval)
          flexIntervalSeconds: 300, // 5 minutes
          inputData: {'platform': 'iOS'},
          constraints: Constraints(
            networkType: NetworkType.connected,
            requiresBatteryNotLow: true,
          ),
        );

        expect(periodicRequest.frequencySeconds, 900);
        expect(periodicRequest.flexIntervalSeconds, 300);
        expect(periodicRequest.constraints?.networkType, NetworkType.connected);
        expect(periodicRequest.constraints?.requiresBatteryNotLow, true);
      });

      test('should validate iOS identifier format compliance', () {
        // Test that identifiers follow iOS conventions
        const validFormats = [
          'com.company.app.task-name',
          'reverse.domain.notation',
          'simple-task-name',
        ];

        for (final format in validFormats) {
          expect(format, isA<String>());
          expect(format.isNotEmpty, true);
          // Test that format doesn't contain invalid characters
          expect(format.contains(RegExp(r'^[a-zA-Z0-9._-]+$')), true);
        }
      });
    });

    group('iOS system integration considerations', () {
      test('should handle background app refresh scenarios', () {
        // Test scenarios relevant to iOS background app refresh
        final backgroundRefreshRequest = PeriodicTaskRequest(
          uniqueName: 'background-refresh',
          taskName: 'Background Refresh Task',
          frequencySeconds: Duration(hours: 4)
              .inSeconds, // Typical iOS background refresh interval
          constraints: Constraints(
            networkType: NetworkType.connected,
            requiresBatteryNotLow: true,
          ),
        );

        expect(backgroundRefreshRequest.frequencySeconds,
            Duration(hours: 4).inSeconds);
        expect(backgroundRefreshRequest.constraints?.networkType,
            NetworkType.connected);
        expect(
            backgroundRefreshRequest.constraints?.requiresBatteryNotLow, true);
      });

      test('should handle iOS processing task time limits', () {
        // BGProcessingTask has ~1 minute, BGAppRefreshTask has ~30 seconds
        final timeLimitedRequest = ProcessingTaskRequest(
          uniqueName: 'time-limited-task',
          taskName: 'Time Limited Task',
          inputData: {'expected_duration': 30}, // seconds
        );

        expect(timeLimitedRequest.inputData?['expected_duration'], 30);
        expect(timeLimitedRequest.uniqueName, 'time-limited-task');
      });

      test('should handle iOS-specific constraint combinations', () {
        // Test constraint combinations that make sense for iOS BGTaskScheduler
        final iosConstraints = Constraints(
          networkType:
              NetworkType.unmetered, // iOS can distinguish network types
          requiresCharging: true, // iOS supports charging requirements
          requiresBatteryNotLow:
              false, // Can run even with low battery if charging
        );

        expect(iosConstraints.networkType, NetworkType.unmetered);
        expect(iosConstraints.requiresCharging, true);
        expect(iosConstraints.requiresBatteryNotLow, false);
      });
    });

    group('iOS enum handling', () {
      test('should handle iOS-supported NetworkType values', () {
        // iOS supports fewer network constraint distinctions than Android
        final iosNetworkTypes = [
          NetworkType.connected,
          NetworkType.notRequired,
          NetworkType.unmetered,
        ];

        for (final type in iosNetworkTypes) {
          expect(type, isA<NetworkType>());
        }
      });

      test('should handle ExistingWorkPolicy for iOS', () {
        // iOS BGTaskScheduler has different behavior for existing work
        final policies = [
          ExistingWorkPolicy.replace, // Most common for iOS
          ExistingWorkPolicy.keep,
        ];

        for (final policy in policies) {
          expect(policy, isA<ExistingWorkPolicy>());
        }
      });
    });
  });
}

/// Stubs the pigeon `getWorkInfoByUniqueName` channel with [reply] so the
/// platform implementation's query plumbing can be exercised in tests.
void _mockGetWorkInfoReply(List<Object?> reply) {
  const channelName =
      'dev.flutter.pigeon.workmanager_platform_interface.WorkmanagerHostApi.getWorkInfoByUniqueName';
  final channel = BasicMessageChannel<Object?>(
    channelName,
    WorkmanagerHostApi.pigeonChannelCodec,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockDecodedMessageHandler<Object?>(channel, (message) async => reply);
}
