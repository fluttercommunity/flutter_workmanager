## 0.9.6

 - **FIX**(ios): run one-off tasks on the main engine to avoid release crash (fixes #653) (#697).
 - **FEAT**(ios): add BGContinuedProcessingTask support (fixes #638) (#700).
 - **FEAT**(android): long-running workers via foreground service (#698).

## 0.9.5

 - **FEAT**(ios): add UIScene lifecycle support (fixes #662) (#696).

## 0.9.4

 - **FEAT**(ios): add BGHealthResearchTaskRequest support (fixes #532) (#693).

## 0.9.3+2

 - **FIX**(ios): restore initialDelay for one-off tasks (#695).

## 0.9.3+1

 - **FIX**(ios): auto-register BGTask launch handlers for scheduled tasks (#692).

## 0.9.3

 - **FEAT**: macOS support via NSBackgroundActivityScheduler (fixes #424) (#689).

## 0.9.2

 - **FIX**(ios): pass taskName to callback and honor initialDelay for one-off tasks (#687).
 - **FIX**(ios): pass inputData to periodic background tasks (#648).
 - **FEAT**: add Swift Package Manager support for iOS (#683).

## 0.9.1+2

 - **FIX**: Android initialization bug and iOS 14 availability annotations (#647).

## 0.9.1+1

 - Update a dependency to the latest release.

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