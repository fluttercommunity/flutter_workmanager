## 0.9.0

> Note: This release has breaking changes.

 - **REFACTOR**: replace debug mode with extensible hook-based system (#630).
 - **REFACTOR**: Migrate internal interfaces to pigeon (#613).
 - **FEAT**: Migrate to federated plugin architecture (#611).
 - **BREAKING** **FIX**: resolve issue #622 - periodic tasks running at incorrect frequencies (#628).


## 0.8.0

### Initial Release
* **BREAKING**: Migrate to federated plugin architecture
* Initial release of the iOS implementation
* Implement all `WorkmanagerPlatform` methods for iOS
* Support for one-off tasks using BGTaskScheduler API
* Support for processing and refresh tasks
* Migrate from `be.tramckrijte` to `dev.fluttercommunity` namespace

### Breaking Changes
* **BREAKING**: Enum values changed from snake_case to camelCase:
  * `NetworkType` values: `not_required` → `notRequired`, `not_roaming` → `notRoaming`, `metered` → `metered` (unchanged)
* **BREAKING**: Removed JSON serialization for inputData - now uses native Map transfer

### New Features
* Add debug notification helper for testing
* Add thumbnail generator for background tasks
* Added comprehensive integration tests

### Bug Fixes
* Fixed `initialDelaySeconds` parameter handling - was previously ignored
* Fixed compilation errors with Map handling
* Fixed inputData type handling - now properly supports all primitive types and lists
* Fixed swapped constraints bug for requiresNetworkConnectivity and requiresExternalPower

### Improvements
* Updated to Flutter 3.32 requirements
* Add Privacy Manifest for App Store compliance
* Replace print statements with proper os_log for better logging
* printScheduledTasks now returns String instead of void
* Better error handling and type safety