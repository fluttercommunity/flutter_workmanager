import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager_ios/workmanager_ios.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkmanagerIOS', () {
    late WorkmanagerIOS workmanager;
    late List<MethodCall> methodCalls;

    setUp(() {
      workmanager = WorkmanagerIOS();
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
      test('should serialize iOS-specific parameters', () async {
        await workmanager.registerOneOffTask(
          'testTask',
          'testTaskName',
          inputData: {'key': 'value'},
          initialDelay: const Duration(seconds: 30),
        );

        expect(methodCalls, hasLength(1));
        expect(methodCalls.first.method, 'registerOneOffTask');

        final arguments =
            Map<String, dynamic>.from(methodCalls.first.arguments);
        expect(arguments['uniqueName'], 'testTask');
        expect(arguments['taskName'], 'testTaskName');
        expect(arguments['inputData'], {'key': 'value'});
        expect(arguments['initialDelaySeconds'], 30);
      });

      test('should handle null optional parameters', () async {
        await workmanager.registerOneOffTask('testTask', 'testTaskName');

        expect(methodCalls, hasLength(1));
        final arguments =
            Map<String, dynamic>.from(methodCalls.first.arguments);
        expect(arguments['inputData'], null);
        expect(arguments['initialDelaySeconds'], null);
      });
    });

    group('registerPeriodicTask', () {
      test('should serialize iOS-specific parameters', () async {
        await workmanager.registerPeriodicTask(
          'periodicTask',
          'periodicTaskName',
          inputData: {'periodic': 'data'},
          initialDelay: const Duration(minutes: 5),
        );

        expect(methodCalls, hasLength(1));
        expect(methodCalls.first.method, 'registerPeriodicTask');

        final arguments =
            Map<String, dynamic>.from(methodCalls.first.arguments);
        expect(arguments['uniqueName'], 'periodicTask');
        expect(arguments['taskName'], 'periodicTaskName');
        expect(arguments['inputData'], {'periodic': 'data'});
        expect(arguments['initialDelaySeconds'], 300);
      });
    });

    group('registerProcessingTask', () {
      test('should serialize processing task parameters', () async {
        await workmanager.registerProcessingTask(
          'processingTask',
          'processingTaskName',
          initialDelay: const Duration(minutes: 10),
          inputData: {'processing': 'data'},
          constraints: Constraints(
            networkType: NetworkType.connected,
            requiresCharging: true,
          ),
        );

        expect(methodCalls, hasLength(1));
        expect(methodCalls.first.method, 'registerProcessingTask');

        final arguments =
            Map<String, dynamic>.from(methodCalls.first.arguments);
        expect(arguments['uniqueName'], 'processingTask');
        expect(arguments['taskName'], 'processingTaskName');
        expect(arguments['inputData'], {'processing': 'data'});
        expect(arguments['initialDelaySeconds'], 600);
        expect(arguments['networkType'], 'connected');
        expect(arguments['requiresCharging'], true);
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
      test('should throw UnsupportedError on iOS', () async {
        expect(
          () => workmanager.cancelByTag('testTag'),
          throwsA(isA<UnsupportedError>()),
        );
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
      test('should throw UnsupportedError on iOS', () async {
        expect(
          () => workmanager.isScheduledByUniqueName('testTask'),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('printScheduledTasks', () {
      test('should return result from method channel', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel(
              'dev.fluttercommunity.workmanager/foreground_channel_work_manager'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'printScheduledTasks') {
              return 'Scheduled tasks: Task1, Task2';
            }
            return null;
          },
        );

        final result = await workmanager.printScheduledTasks();

        expect(result, 'Scheduled tasks: Task1, Task2');
      });

      test('should return default message when method channel returns null',
          () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel(
              'dev.fluttercommunity.workmanager/foreground_channel_work_manager'),
          (MethodCall methodCall) async => null,
        );

        final result = await workmanager.printScheduledTasks();

        expect(result, 'No scheduled tasks information available');
      });
    });
  });
}
