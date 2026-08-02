import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  group('StopReason', () {
    test('maps known WorkManager stop reasons', () {
      expect(StopReason.unknown.rawValue, 0);
      expect(StopReason.timeout.rawValue, 1);
      expect(StopReason.preempt.rawValue, 2);
      expect(StopReason.cancelledByApp.rawValue, 3);
      expect(StopReason.systemIgnoredCancelledByApp.rawValue, 4);
      expect(StopReason.backgroundRestriction.rawValue, 5);
      expect(StopReason.estimatedAppGpuLimit.rawValue, 6);
      expect(StopReason.deviceState.rawValue, 7);
      expect(StopReason.appStandby.rawValue, 8);
      expect(StopReason.deviceIdle.rawValue, 9);
    });

    test('fromRawValue round-trips every known reason', () {
      for (final reason in StopReason.values) {
        expect(StopReason.fromRawValue(reason.rawValue), reason);
      }
    });

    test('fromRawValue falls back to unknown for unrecognized values', () {
      expect(StopReason.fromRawValue(-1), StopReason.unknown);
      expect(StopReason.fromRawValue(42), StopReason.unknown);
    });
  });
}
