## Future

### Dependencies
* Updated androidx.work from 2.9.0 to 2.10.2

### Breaking Changes
* **BREAKING**: `registerPeriodicTask` now uses `ExistingPeriodicWorkPolicy`
  * Replace `ExistingWorkPolicy` parameter with `ExistingPeriodicWorkPolicy`

### New Features
* Add `NotificationDebugHandler` for debug notifications with configurable channels
* Add `LoggingDebugHandler` for system log-based debugging
* Add `TaskStatus.SCHEDULED` and `TaskStatus.RESCHEDULED` for better task lifecycle tracking

### Bug Fixes
* Fix periodic tasks running at wrong frequency when re-registered (#622)
  * Changed default policy from `KEEP` to `UPDATE`
  * `UPDATE` ensures new task configurations replace existing ones
* Fix crash when background task callback is null (thanks @jonathanduke, @Muneeza-PT)
* Fix retry detection using `runAttemptCount` to properly identify retrying tasks

## 0.8.0

### Initial Release
* **BREAKING**: Migrate to federated plugin architecture
* Initial release of the Android implementation
* Implement all `WorkmanagerPlatform` methods for Android
* Support for one-off and periodic tasks using WorkManager API
* Migrate from `be.tramckrijte` to `dev.fluttercommunity` namespace

### Breaking Changes
* **BREAKING**: Enum values changed from snake_case to camelCase:
  * `NetworkType` values: `not_required` → `notRequired`, `not_roaming` → `notRoaming`, `metered` → `metered` (unchanged)
  * `OutOfQuotaPolicy` values: `run_as_non_expedited_work_request` → `runAsNonExpeditedWorkRequest`, `drop_work_request` → `dropWorkRequest`
* **BREAKING**: Removed JSON serialization for inputData - now uses native Map transfer

### New Features
* Add `isScheduledByUniqueName` method to check if a periodic task is scheduled by its unique name
* Support for constraints: network type, battery not low, charging, device idle, storage not low
* Support for backoff policies: linear and exponential
* Added comprehensive integration tests

### Bug Fixes
* Fixed NullPointerException when `isInDebugMode` was not properly initialized
* Fixed inputData type handling - now properly supports all primitive types and lists
* Fixed v2 embedding import in BackgroundWorker

### Improvements
* Updated to Android target SDK 35
* Updated Android dependencies to latest versions
* Improved CI/CD with Android emulator caching
* Better error handling and type safety
* Fix documentation formatting and typo in BackgroundWorker