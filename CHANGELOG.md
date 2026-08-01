# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2026-08-01

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`workmanager` - `v0.9.1`](#workmanager---v091)
 - [`workmanager_android` - `v0.9.1`](#workmanager_android---v091)
 - [`workmanager_apple` - `v0.9.3`](#workmanager_apple---v093)

---

#### `workmanager` - `v0.9.1`

 - **FEAT**: support typed Lists/Maps in inputData (fixes #426) (#690).
 - **FEAT**: macOS support via NSBackgroundActivityScheduler (fixes #424) (#689).

#### `workmanager_android` - `v0.9.1`

 - **FEAT**: support typed Lists/Maps in inputData (fixes #426) (#690).

#### `workmanager_apple` - `v0.9.3`

 - **FEAT**: macOS support via NSBackgroundActivityScheduler (fixes #424) (#689).


## 2026-08-01

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`workmanager` - `v0.9.0+4`](#workmanager---v0904)
 - [`workmanager_android` - `v0.9.0+3`](#workmanager_android---v0903)
 - [`workmanager_apple` - `v0.9.2`](#workmanager_apple---v092)
 - [`workmanager_platform_interface` - `v0.9.2`](#workmanager_platform_interface---v092)

---

#### `workmanager` - `v0.9.0+4`

 - **FIX**(ios): pass taskName to callback and honor initialDelay for one-off tasks (#687).

#### `workmanager_android` - `v0.9.0+3`

 - **FIX**: remove kotlin-android since AGP 9 supports it https://github.com/fluttercommunity/flutter_workmanager/issues/667 (#682).
 - **FIX**: Failed host lookup, by bumping androidx.work:work-runtime to 2.11.2 and Android minSdkVersion to 23 (#679).
 - **FIX**: NullPointerException by replacing companion FlutterLoader with FlutterInjector singleton (#678).

#### `workmanager_apple` - `v0.9.2`

 - **FIX**(ios): pass taskName to callback and honor initialDelay for one-off tasks (#687).
 - **FIX**(ios): pass inputData to periodic background tasks (#648).
 - **FEAT**: add Swift Package Manager support for iOS (#683).

#### `workmanager_platform_interface` - `v0.9.2`

 - **FEAT**: add Swift Package Manager support for iOS (#683).


## 2026-08-01

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`workmanager` - `v0.9.0+4`](#workmanager---v0904)
 - [`workmanager_android` - `v0.9.0+3`](#workmanager_android---v0903)
 - [`workmanager_apple` - `v0.9.2`](#workmanager_apple---v092)
 - [`workmanager_platform_interface` - `v0.9.2`](#workmanager_platform_interface---v092)

---

#### `workmanager` - `v0.9.0+4`

 - **FIX**(ios): pass taskName to callback and honor initialDelay for one-off tasks (#687).

#### `workmanager_android` - `v0.9.0+3`

 - **FIX**: remove kotlin-android since AGP 9 supports it https://github.com/fluttercommunity/flutter_workmanager/issues/667 (#682).
 - **FIX**: Failed host lookup, by bumping androidx.work:work-runtime to 2.11.2 and Android minSdkVersion to 23 (#679).
 - **FIX**: NullPointerException by replacing companion FlutterLoader with FlutterInjector singleton (#678).

#### `workmanager_apple` - `v0.9.2`

 - **FIX**(ios): pass taskName to callback and honor initialDelay for one-off tasks (#687).
 - **FIX**(ios): pass inputData to periodic background tasks (#648).
 - **FEAT**: add Swift Package Manager support for iOS (#683).

#### `workmanager_platform_interface` - `v0.9.2`

 - **FEAT**: add Swift Package Manager support for iOS (#683).


## 2025-08-31

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`workmanager_android` - `v0.9.0+2`](#workmanager_android---v0902)
 - [`workmanager_apple` - `v0.9.1+2`](#workmanager_apple---v0912)
 - [`workmanager_platform_interface` - `v0.9.1+1`](#workmanager_platform_interface---v0911)
 - [`workmanager` - `v0.9.0+3`](#workmanager---v0903)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `workmanager` - `v0.9.0+3`

---

#### `workmanager_android` - `v0.9.0+2`

 - **FIX**: Android initialization bug and iOS 14 availability annotations (#647).

#### `workmanager_apple` - `v0.9.1+2`

 - **FIX**: Android initialization bug and iOS 14 availability annotations (#647).

#### `workmanager_platform_interface` - `v0.9.1+1`

 - **FIX**: Android initialization bug and iOS 14 availability annotations (#647).


## 2025-08-06

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`workmanager_android` - `v0.9.0+1`](#workmanager_android---v0901)
 - [`workmanager_platform_interface` - `v0.9.1`](#workmanager_platform_interface---v091)
 - [`workmanager` - `v0.9.0+2`](#workmanager---v0902)
 - [`workmanager_apple` - `v0.9.1+1`](#workmanager_apple---v0911)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `workmanager` - `v0.9.0+2`
 - `workmanager_apple` - `v0.9.1+1`

---

#### `workmanager_android` - `v0.9.0+1`

 - **FIX**: prevent NullPointerException in BackgroundWorker.getDartTask (#636).

#### `workmanager_platform_interface` - `v0.9.1`

 - **FEAT**: add iOS Swift Package Manager support (#631).


## 2025-08-01

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`workmanager_apple` - `v0.9.1`](#workmanager_apple---v091)
 - [`workmanager` - `v0.9.0+1`](#workmanager---v0901)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `workmanager` - `v0.9.0+1`

---

#### `workmanager_apple` - `v0.9.1`

 - **FEAT**: add iOS Swift Package Manager support (#631).


## 2025-07-31

### Changes

---

Packages with breaking changes:

 - [`workmanager` - `v0.9.0`](#workmanager---v090)
 - [`workmanager_android` - `v0.9.0`](#workmanager_android---v090)
 - [`workmanager_apple` - `v0.9.0`](#workmanager_apple---v090)
 - [`workmanager_platform_interface` - `v0.9.0`](#workmanager_platform_interface---v090)

Packages with other changes:

 - There are no other changes in this release.

---

#### `workmanager` - `v0.9.0`

 - **REFACTOR**: replace debug mode with extensible hook-based system (#630).
 - **REFACTOR**: Migrate internal interfaces to pigeon (#613).
 - **FIX**: resolve critical null handling crashes from contributor reports (#626).
 - **FEAT**: Migrate to federated plugin architecture (#611).
 - **BREAKING** **FIX**: resolve issue #622 - periodic tasks running at incorrect frequencies (#628).

#### `workmanager_android` - `v0.9.0`

 - **REFACTOR**: replace debug mode with extensible hook-based system (#630).
 - **REFACTOR**: Migrate internal interfaces to pigeon (#613).
 - **FIX**: resolve critical null handling crashes from contributor reports (#626).
 - **FEAT**: Migrate to federated plugin architecture (#611).
 - **BREAKING** **FIX**: resolve issue #622 - periodic tasks running at incorrect frequencies (#628).

#### `workmanager_apple` - `v0.9.0`

 - **REFACTOR**: replace debug mode with extensible hook-based system (#630).
 - **REFACTOR**: Migrate internal interfaces to pigeon (#613).
 - **FEAT**: Migrate to federated plugin architecture (#611).
 - **BREAKING** **FIX**: resolve issue #622 - periodic tasks running at incorrect frequencies (#628).

#### `workmanager_platform_interface` - `v0.9.0`

 - **REFACTOR**: replace debug mode with extensible hook-based system (#630).
 - **REFACTOR**: Migrate internal interfaces to pigeon (#613).
 - **FEAT**: Migrate to federated plugin architecture (#611).
 - **BREAKING** **FIX**: resolve issue #622 - periodic tasks running at incorrect frequencies (#628).

