/// An enumeration of the conflict resolution policies in case of a collision.
enum ExistingWorkPolicy {
  /// If there is existing pending (uncompleted) work with the same unique name, append the newly-specified work as a child of all the leaves of that work sequence.
  append,

  /// If there is existing pending (uncompleted) work with the same unique name, it will be updated the new specification.
  update,

  /// If there is existing pending (uncompleted) work with the same unique name, do nothing.
  keep,

  /// If there is existing pending (uncompleted) work with the same unique name, cancel and delete it.
  replace
}

/// An enumeration of various network types that can be used as Constraints for work.
///
/// Fully supported on Android.
///
/// On iOS, this enumeration is used to define whether a piece of work requires
/// internet connectivity, by checking for either [NetworkType.connected] or
/// [NetworkType.metered].
enum NetworkType {
  /// Any working network connection is required for this work.
  connected,

  /// A metered network connection is required for this work.
  metered,

  /// Default value. A network is not required for this work.
  not_required,

  /// A non-roaming network connection is required for this work.
  not_roaming,

  /// An unmetered network connection is required for this work.
  unmetered,

  /// A temporarily unmetered Network. This capability will be set for
  /// networks that are generally metered, but are currently unmetered.
  ///
  /// Android API 30+
  temporarily_unmetered,
}

/// An enumeration of policies that help determine out of quota behavior for expedited jobs.
///
/// Only supported on Android.
enum OutOfQuotaPolicy {
  /// When the app does not have any expedited job quota, the expedited work request will
  /// fallback to a regular work request.
  run_as_non_expedited_work_request,

  /// When the app does not have any expedited job quota, the expedited work request will
  /// we dropped and no work requests are enqueued.
  drop_work_request,
}

/// An enumeration of backoff policies when retrying work.
/// These policies are used when you have a return ListenableWorker.Result.retry() from a worker to determine the correct backoff time.
/// Backoff policies are set in WorkRequest.Builder.setBackoffCriteria(BackoffPolicy, long, TimeUnit) or one of its variants.
enum BackoffPolicy {
  /// Used to indicate that WorkManager should increase the backoff time exponentially
  exponential,

  /// Used to indicate that WorkManager should increase the backoff time linearly
  linear
}

/// A specification of the requirements that need to be met before a WorkRequest can run.
/// By default, WorkRequests do not have any requirements and can run immediately.
/// By adding requirements, you can make sure that work only runs in certain situations -
/// for example, when you have an unmetered network and are charging.
class Constraints {
  /// An enumeration of various network types that can be used as Constraints for work.
  final NetworkType networkType;

  /// `true` if the work should only execute when the battery isn't low.
  ///
  /// Only supported on Android.
  final bool? requiresBatteryNotLow;

  /// `true` if the work should only execute while the device is charging.
  final bool? requiresCharging;

  /// `true` if the work should only execute while the device is idle.
  ///
  /// Only supported on Android.
  final bool? requiresDeviceIdle;

  /// `true` if the work should only execute when the storage isn't low.
  ///
  /// Only supported on Android.
  final bool? requiresStorageNotLow;

  Constraints({
    required this.networkType,
    this.requiresBatteryNotLow,
    this.requiresCharging,
    this.requiresDeviceIdle,
    this.requiresStorageNotLow,
  });
}

/// Background App Refresh permission states. Currently only available in iOS.
///
/// On iOS user can disable Background App Refresh permission anytime, hence
/// background tasks can only run if user has granted the permission.
/// [Workmanager().checkBackgroundRefreshPermission()] can be used to check the
/// permission.
enum BackgroundRefreshPermissionState {
  /// Background app refresh is enabled in OS Setting
  available,

  /// Background app refresh is disabled in OS Setting. Permission should be requested from user
  denied,

  /// OS setting is under parental control etc. Can't be changed by user
  restricted,

  /// Unknown state
  unknown
}
