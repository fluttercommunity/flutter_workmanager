## 0.9.0+2

 - **FIX**: Android initialization bug and iOS 14 availability annotations (#647).

## 0.9.0+1

 - **FIX**: prevent NullPointerException in BackgroundWorker.getDartTask (#636).

## 0.9.0

> Note: This release has breaking changes.

 - **REFACTOR**: replace debug mode with extensible hook-based system (#630).
 - **REFACTOR**: Migrate internal interfaces to pigeon (#613).
 - **FIX**: resolve critical null handling crashes from contributor reports (#626).
 - **FEAT**: Migrate to federated plugin architecture (#611).
 - **BREAKING** **FIX**: resolve issue #622 - periodic tasks running at incorrect frequencies (#628).


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