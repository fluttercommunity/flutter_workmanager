import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/src/options.dart';
import 'package:workmanager/src/workmanager.dart';

void main() {
  group("toInitializeMethodArgument", () {
    test("no callbackHandle", () {
      expect(
          () =>
              JsonMapperHelper.toInitializeMethodArgument(isInDebugMode: true),
          throwsAssertionError);
    });

    test("all arguments given", () {
      expect(
          JsonMapperHelper.toInitializeMethodArgument(
              isInDebugMode: true, callbackHandle: 9001),
          {'isInDebugMode': true, 'callbackHandle': 9001});
    });
  });

  group("toRegisterMethodArgument", () {
    group("invalid inputs", () {
      test("no unique name", () {
        expect(
            () =>
                JsonMapperHelper.toRegisterMethodArgument(isInDebugMode: true),
            throwsAssertionError);
      });

      test("no value", () {
        expect(
            () => JsonMapperHelper.toRegisterMethodArgument(
                isInDebugMode: true, uniqueName: "uniqueName"),
            throwsAssertionError);
      });

      test("initial delay was null", () {
        expect(
          () => JsonMapperHelper.toRegisterMethodArgument(
            isInDebugMode: true,
            uniqueName: "uniqueName",
            taskName: "taskName",
            initialDelay: null,
          ),
          throwsNoSuchMethodError,
        );
      });

      test("backoff policy was null", () {
        expect(
            () => JsonMapperHelper.toRegisterMethodArgument(
                  isInDebugMode: true,
                  uniqueName: "uniqueName",
                  taskName: "taskName",
                  initialDelay: Duration(seconds: 1),
                  backoffPolicyDelay: null,
                ),
            throwsNoSuchMethodError);
      });
    });

    group("simple assertions", () {
      test("minimum required fields", () {
        expect(
            JsonMapperHelper.toRegisterMethodArgument(
              isInDebugMode: true,
              uniqueName: "uniqueName",
              taskName: "taskName",
              initialDelay: Duration(seconds: 1),
              backoffPolicyDelay: Duration(seconds: 1),
            ),
            {
              'isInDebugMode': true,
              'uniqueName': 'uniqueName',
              'taskName': 'taskName',
              'tag': null,
              'frequency': null,
              'existingWorkPolicy': null,
              'initialDelaySeconds': 1,
              'networkType': null,
              'requiresBatteryNotLow': null,
              'requiresCharging': null,
              'requiresDeviceIdle': null,
              'requiresStorageNotLow': null,
              'backoffPolicyType': null,
              'backoffDelayInMilliseconds': 1000,
              'payload': null,
            });
      });

      test("All fields filled in", () {
        expect(
            JsonMapperHelper.toRegisterMethodArgument(
              isInDebugMode: true,
              uniqueName: "uniqueName",
              taskName: "taskName",
              frequency: Duration(seconds: 1),
              tag: "tag",
              existingWorkPolicy: ExistingWorkPolicy.replace,
              initialDelay: Duration(seconds: 2),
              constraints: Constraints(
                networkType: NetworkType.connected,
                requiresBatteryNotLow: false,
                requiresDeviceIdle: true,
                requiresStorageNotLow: false,
                requiresCharging: true,
              ),
              backoffPolicy: BackoffPolicy.linear,
              backoffPolicyDelay: Duration(seconds: 3),
              payload: <String, dynamic>{"key": "value"},
            ),
            {
              'isInDebugMode': true,
              'uniqueName': 'uniqueName',
              'taskName': 'taskName',
              'tag': 'tag',
              'frequency': 1,
              'existingWorkPolicy': 'replace',
              'initialDelaySeconds': 2,
              'networkType': 'connected',
              'requiresBatteryNotLow': false,
              'requiresCharging': true,
              'requiresDeviceIdle': true,
              'requiresStorageNotLow': false,
              'backoffPolicyType': 'linear',
              'backoffDelayInMilliseconds': 3000,
              'payload': jsonEncode({"key": "value"}),
            });
      });
    });

    group("constraints", () {
      [
        [
          Constraints(
            networkType: NetworkType.connected,
            requiresCharging: true,
            requiresStorageNotLow: true,
            requiresDeviceIdle: true,
            requiresBatteryNotLow: true,
          ),
          {
            'isInDebugMode': true,
            'uniqueName': 'uniqueName',
            'taskName': 'taskName',
            'tag': null,
            'frequency': null,
            'existingWorkPolicy': null,
            'initialDelaySeconds': 1,
            'networkType': 'connected',
            'requiresBatteryNotLow': true,
            'requiresCharging': true,
            'requiresDeviceIdle': true,
            'requiresStorageNotLow': true,
            'backoffPolicyType': null,
            'backoffDelayInMilliseconds': 1000,
            'payload': null,
          }
        ],
        [
          Constraints(
            networkType: NetworkType.metered,
            requiresCharging: false,
            requiresStorageNotLow: false,
            requiresDeviceIdle: false,
            requiresBatteryNotLow: false,
          ),
          {
            'isInDebugMode': true,
            'uniqueName': 'uniqueName',
            'taskName': 'taskName',
            'tag': null,
            'frequency': null,
            'existingWorkPolicy': null,
            'initialDelaySeconds': 1,
            'networkType': 'metered',
            'requiresBatteryNotLow': false,
            'requiresCharging': false,
            'requiresDeviceIdle': false,
            'requiresStorageNotLow': false,
            'backoffPolicyType': null,
            'backoffDelayInMilliseconds': 1000,
            'payload': null,
          }
        ],
        [
          Constraints(networkType: NetworkType.metered),
          {
            'isInDebugMode': true,
            'uniqueName': 'uniqueName',
            'taskName': 'taskName',
            'tag': null,
            'frequency': null,
            'existingWorkPolicy': null,
            'initialDelaySeconds': 1,
            'networkType': 'metered',
            'requiresBatteryNotLow': null,
            'requiresCharging': null,
            'requiresDeviceIdle': null,
            'requiresStorageNotLow': null,
            'backoffPolicyType': null,
            'backoffDelayInMilliseconds': 1000,
            'payload': null,
          }
        ],
        [
          Constraints(
            networkType: NetworkType.not_roaming,
            requiresCharging: false,
            requiresStorageNotLow: true,
            requiresDeviceIdle: false,
            requiresBatteryNotLow: true,
          ),
          {
            'isInDebugMode': true,
            'uniqueName': 'uniqueName',
            'taskName': 'taskName',
            'tag': null,
            'frequency': null,
            'existingWorkPolicy': null,
            'initialDelaySeconds': 1,
            'networkType': 'not_roaming',
            'requiresBatteryNotLow': true,
            'requiresCharging': false,
            'requiresDeviceIdle': false,
            'requiresStorageNotLow': true,
            'backoffPolicyType': null,
            'backoffDelayInMilliseconds': 1000,
            'payload': null,
          }
        ],
        [
          Constraints(
            networkType: NetworkType.unmetered,
            requiresCharging: true,
            requiresStorageNotLow: true,
            requiresDeviceIdle: true,
            requiresBatteryNotLow: true,
          ),
          {
            'isInDebugMode': true,
            'uniqueName': 'uniqueName',
            'taskName': 'taskName',
            'tag': null,
            'frequency': null,
            'existingWorkPolicy': null,
            'initialDelaySeconds': 1,
            'networkType': 'unmetered',
            'requiresBatteryNotLow': true,
            'requiresCharging': true,
            'requiresDeviceIdle': true,
            'requiresStorageNotLow': true,
            'backoffPolicyType': null,
            'backoffDelayInMilliseconds': 1000,
            'payload': null,
          }
        ],
      ].forEach((constraintTuple) {
        test("map to JSON", () {
          expect(
            JsonMapperHelper.toRegisterMethodArgument(
              isInDebugMode: true,
              uniqueName: "uniqueName",
              taskName: "taskName",
              initialDelay: Duration(seconds: 1),
              backoffPolicyDelay: Duration(seconds: 1),
              constraints: constraintTuple.first,
            ),
            constraintTuple[1],
          );
        });
      });
    });

    group("Json Mapper enum parsing", () {
      [
        [ExistingWorkPolicy.keep, "keep"],
        [ExistingWorkPolicy.append, "append"],
        [ExistingWorkPolicy.replace, "replace"],
      ].forEach((existingWorkPolicy) {
        test("for workpolicy ${existingWorkPolicy.first}", () {
          expect(
            JsonMapperHelper.toRegisterMethodArgument(
                isInDebugMode: true,
                uniqueName: "uniqueName",
                taskName: "taskName",
                initialDelay: Duration(seconds: 1),
                backoffPolicyDelay: Duration(seconds: 1),
                existingWorkPolicy: existingWorkPolicy.first),
            {
              'isInDebugMode': true,
              'uniqueName': 'uniqueName',
              'taskName': 'taskName',
              'tag': null,
              'frequency': null,
              'existingWorkPolicy': existingWorkPolicy[1],
              'initialDelaySeconds': 1,
              'networkType': null,
              'requiresBatteryNotLow': null,
              'requiresCharging': null,
              'requiresDeviceIdle': null,
              'requiresStorageNotLow': null,
              'backoffPolicyType': null,
              'backoffDelayInMilliseconds': 1000,
              'payload': null,
            },
          );
        });
      });

      [
        [BackoffPolicy.exponential, "exponential"],
        [BackoffPolicy.linear, "linear"],
      ].forEach((backOffPolicy) {
        test("for workpolicy ${backOffPolicy.first}", () {
          expect(
            JsonMapperHelper.toRegisterMethodArgument(
              isInDebugMode: true,
              uniqueName: "uniqueName",
              taskName: "taskName",
              initialDelay: Duration(seconds: 1),
              backoffPolicyDelay: Duration(seconds: 1),
              backoffPolicy: backOffPolicy.first,
            ),
            {
              'isInDebugMode': true,
              'uniqueName': 'uniqueName',
              'taskName': 'taskName',
              'tag': null,
              'frequency': null,
              'existingWorkPolicy': null,
              'initialDelaySeconds': 1,
              'networkType': null,
              'requiresBatteryNotLow': null,
              'requiresCharging': null,
              'requiresDeviceIdle': null,
              'requiresStorageNotLow': null,
              'backoffPolicyType': backOffPolicy[1],
              'backoffDelayInMilliseconds': 1000,
              'payload': null,
            },
          );
        });
      });
    });
  });
}
