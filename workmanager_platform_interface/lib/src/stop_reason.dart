/// The reason a running background task was stopped by the platform before it
/// finished.
///
/// The values mirror Android's WorkManager
/// [StopReason](https://developer.android.com/reference/androidx/work/StopReason)
/// constants. Android 12 (API 31) is the first version where WorkManager
/// reports the actual reason; on older Android versions and on platforms
/// without an equivalent concept the reason is reported as [unknown].
enum StopReason {
  /// The reason could not be determined (Android < 12, or a platform with no
  /// equivalent concept).
  unknown(0),

  /// The task ran for longer than its allowed time limit.
  timeout(1),

  /// The task was stopped because a higher-priority task preempted it.
  preempt(2),

  /// The task was cancelled by the app.
  cancelledByApp(3),

  /// The task was cancelled by the app, but the system ignored the
  /// cancellation and the worker ran to completion.
  systemIgnoredCancelledByApp(4),

  /// The app is in a background restriction state.
  backgroundRestriction(5),

  /// The app reached an estimated GPU memory limit.
  estimatedAppGpuLimit(6),

  /// The device entered a state that stops the task (e.g. battery saver).
  deviceState(7),

  /// The app entered App Standby.
  appStandby(8),

  /// The device entered Doze mode.
  deviceIdle(9);

  const StopReason(this.rawValue);

  /// The integer value as reported by the platform.
  final int rawValue;

  /// Maps a platform-reported [rawValue] to the closest [StopReason].
  ///
  /// Values that are not recognized (e.g. new stop reasons added by future
  /// WorkManager releases) map to [StopReason.unknown].
  static StopReason fromRawValue(int rawValue) => values.firstWhere(
        (reason) => reason.rawValue == rawValue,
        orElse: () => StopReason.unknown,
      );
}
