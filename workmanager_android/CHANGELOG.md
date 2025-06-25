## 0.8.0

* **BREAKING**: Migrate to federated plugin architecture
* Initial release of the Android implementation
* Implement all `WorkmanagerPlatform` methods for Android
* Support for one-off and periodic tasks using WorkManager API
* Support for constraints: network type, battery not low, charging, device idle, storage not low
* Support for backoff policies: linear and exponential
* Add `isScheduled` method to check if a periodic task is scheduled (Android only)
* Migrate from `be.tramckrijte` to `dev.fluttercommunity` namespace