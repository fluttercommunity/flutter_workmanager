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