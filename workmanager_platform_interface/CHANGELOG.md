## 0.9.1+1

 - **FIX**: Android initialization bug and iOS 14 availability annotations (#647).

## 0.9.1

 - **FEAT**: add iOS Swift Package Manager support (#631).

## 0.9.0

> Note: This release has breaking changes.

 - **REFACTOR**: replace debug mode with extensible hook-based system (#630).
 - **REFACTOR**: Migrate internal interfaces to pigeon (#613).
 - **FEAT**: Migrate to federated plugin architecture (#611).
 - **BREAKING** **FIX**: resolve issue #622 - periodic tasks running at incorrect frequencies (#628).


## 0.8.0

### Initial Release
* **BREAKING**: Migrate to federated plugin architecture
* Initial release of the platform interface package
* Define `WorkmanagerPlatform` abstract class with all method signatures
* Define data classes: `WorkmanagerConfig`, `Constraints`, `BackoffPolicy`

### Breaking Changes
* **BREAKING**: Enum values changed from snake_case to camelCase:
  * `NetworkType` values: `not_required` → `notRequired`, `not_roaming` → `notRoaming`, `metered` → `metered` (unchanged)
  * `OutOfQuotaPolicy` values: `run_as_non_expedited_work_request` → `runAsNonExpeditedWorkRequest`, `drop_work_request` → `dropWorkRequest`
* **BREAKING**: Removed JSON serialization for inputData - now uses native Map transfer

### Features
* Add comprehensive documentation for all public APIs
* Support for all constraint types: network, battery, charging, device idle, storage
* Support for linear and exponential backoff policies
* Type-safe data transfer between Dart and native platforms

### Improvements
* Updated to Flutter 3.32 and flutter_lints 6.0.0
* Better error handling and type safety throughout the interface