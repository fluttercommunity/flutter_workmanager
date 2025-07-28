## Project Workflow
- Project uses GitHub Actions
- Use `ktlint -F .` in root folder to format Kotlin code
- Use SwiftLint for code formatting
- Always resolve formatting and analyzer errors before completing a task

## Pigeon Code Generation
- Pigeon configuration is in `workmanager_platform_interface/pigeons/workmanager_api.dart`
- To regenerate Pigeon files: `cd workmanager_platform_interface && dart run pigeon --input pigeons/workmanager_api.dart`
- Generated files:
  - Dart: `workmanager_platform_interface/lib/src/pigeon/workmanager_api.g.dart`
  - Kotlin: `workmanager_android/android/src/main/kotlin/dev/fluttercommunity/workmanager/pigeon/WorkmanagerApi.g.kt`
  - Swift: `workmanager_apple/ios/Classes/pigeon/WorkmanagerApi.g.swift`
- Do not manually edit generated files (*.g.* files)

## Code Formatting Configuration
- `.editorconfig` in root folder configures ktlint to ignore Pigeon-generated Kotlin files
- `.swiftlint.yml` in root folder excludes Pigeon-generated Swift files from linting

## GitHub Actions Configuration
- Format checks: `.github/workflows/format.yml`
  - Runs dart format, ktlint, and SwiftLint
- Tests: `.github/workflows/test.yml`
  - `test`: Runs Dart unit tests
  - `native_ios_tests`: Runs iOS native tests with xcodebuild
  - `native_android_tests`: Runs Android native tests with Gradle
  - `drive_ios`: Runs Flutter integration tests on iOS simulator
  - `drive_android`: Runs Flutter integration tests on Android emulator