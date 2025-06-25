import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager_android/workmanager_android.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkmanagerAndroid', () {
    late WorkmanagerAndroid workmanager;
    late List<MethodCall> methodCalls;

    setUp(() {
      workmanager = WorkmanagerAndroid();
      methodCalls = <MethodCall>[];

      // Mock the method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(
            'dev.fluttercommunity.workmanager/foreground_channel_work_manager'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(
            'dev.fluttercommunity.workmanager/foreground_channel_work_manager'),
        null,
      );
    });

    group('registerOneOffTask', () {
      test('should serialize all parameters correctly', () async {
        await workmanager.registerOneOffTask(
          'testTask',
          'testTaskName',
          inputData: {'key': 'value'},
          initialDelay: const Duration(seconds: 30),
          constraints: Constraints(
            networkType: NetworkType.connected,
            requiresCharging: true,
            requiresBatteryNotLow: false,
            requiresDeviceIdle: true,
            requiresStorageNotLow: false,
          ),
          existingWorkPolicy: ExistingWorkPolicy.replace,
          backoffPolicy: BackoffPolicy.exponential,
          backoffPolicyDelay: const Duration(minutes: 1),
          tag: 'testTag',
          outOfQuotaPolicy: OutOfQuotaPolicy.runAsNonExpeditedWorkRequest,
        );

        expect(methodCalls, hasLength(1));
        expect(methodCalls.first.method, 'registerOneOffTask');

        final arguments =
            Map<String, dynamic>.from(methodCalls.first.arguments);
        expect(arguments['uniqueName'], 'testTask');
        expect(arguments['taskName'], 'testTaskName');
        expect(arguments['inputData'], {'key': 'value'});
        expect(arguments['initialDelaySeconds'], 30);
        expect(arguments['networkType'], 'connected');
        expect(arguments['requiresCharging'], true);
        expect(arguments['requiresBatteryNotLow'], false);
        expect(arguments['requiresDeviceIdle'], true);
        expect(arguments['requiresStorageNotLow'], false);
        expect(arguments['existingWorkPolicy'], 'replace');
        expect(arguments['backoffPolicy'], 'exponential');
        expect(arguments['backoffDelayInMilliseconds'], 60000);
        expect(arguments['tag'], 'testTag');
        expect(
            arguments['outOfQuotaPolicy'], 'runAsNonExpeditedWorkRequest');
      });

      test('should handle null optional parameters', () async {
        await workmanager.registerOneOffTask('testTask', 'testTaskName');

        expect(methodCalls, hasLength(1));
        final arguments =
            Map<String, dynamic>.from(methodCalls.first.arguments);
        expect(arguments['inputData'], null);
        expect(arguments['initialDelaySeconds'], null);
        expect(arguments['networkType'], null);
        expect(arguments['requiresCharging'], null);
        expect(arguments['requiresBatteryNotLow'], null);
        expect(arguments['requiresDeviceIdle'], null);
        expect(arguments['requiresStorageNotLow'], null);
        expect(arguments['existingWorkPolicy'], null);
        expect(arguments['backoffPolicy'], null);
        expect(arguments['backoffDelayInMilliseconds'], null);
        expect(arguments['tag'], null);
        expect(arguments['outOfQuotaPolicy'], null);
      });
    });

    group('registerPeriodicTask', () {
      test('should serialize all parameters correctly', () async {
        await workmanager.registerPeriodicTask(
          'periodicTask',
          'periodicTaskName',
          frequency: const Duration(hours: 1),
          flexInterval: const Duration(minutes: 15),
          inputData: {'periodic': 'data'},
          initialDelay: const Duration(minutes: 5),
          constraints: Constraints(networkType: NetworkType.unmetered),
          existingWorkPolicy: ExistingWorkPolicy.keep,
          backoffPolicy: BackoffPolicy.linear,
          backoffPolicyDelay: const Duration(seconds: 30),
          tag: 'periodicTag',
        );

        expect(methodCalls, hasLength(1));
        expect(methodCalls.first.method, 'registerPeriodicTask');

        final arguments =
            Map<String, dynamic>.from(methodCalls.first.arguments);
        expect(arguments['uniqueName'], 'periodicTask');
        expect(arguments['taskName'], 'periodicTaskName');
        expect(arguments['frequencySeconds'], 3600);
        expect(arguments['flexIntervalSeconds'], 900);
        expect(arguments['inputData'], {'periodic': 'data'});
        expect(arguments['initialDelaySeconds'], 300);
        expect(arguments['networkType'], 'unmetered');
        expect(arguments['existingWorkPolicy'], 'keep');
        expect(arguments['backoffPolicy'], 'linear');
        expect(arguments['backoffDelayInMilliseconds'], 30000);
        expect(arguments['tag'], 'periodicTag');
      });
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

    group('cancelByUniqueName', () {
      test('should call correct method with parameters', () async {
        await workmanager.cancelByUniqueName('testTask');

        expect(methodCalls, hasLength(1));
        expect(methodCalls.first.method, 'cancelTaskByUniqueName');
        expect(methodCalls.first.arguments, {'uniqueName': 'testTask'});
      });
    });

    group('cancelByTag', () {
      test('should call correct method with parameters', () async {
        await workmanager.cancelByTag('testTag');

        expect(methodCalls, hasLength(1));
        expect(methodCalls.first.method, 'cancelTaskByTag');
        expect(methodCalls.first.arguments, {'tag': 'testTag'});
      });
    });

    group('cancelAll', () {
      test('should call correct method', () async {
        await workmanager.cancelAll();

        expect(methodCalls, hasLength(1));
        expect(methodCalls.first.method, 'cancelAllTasks');
        expect(methodCalls.first.arguments, null);
      });
    });

    group('isScheduledByUniqueName', () {
      test('should return result from method channel', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel(
              'dev.fluttercommunity.workmanager/foreground_channel_work_manager'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'isScheduledByUniqueName') {
              return true;
            }
            return null;
          },
        );

        final result = await workmanager.isScheduledByUniqueName('testTask');

        expect(result, true);
      });

      test('should return false when method channel returns null', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel(
              'dev.fluttercommunity.workmanager/foreground_channel_work_manager'),
          (MethodCall methodCall) async => null,
        );

        final result = await workmanager.isScheduledByUniqueName('testTask');

        expect(result, false);
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
  });
}
