## Project Workflow
- Project uses GitHub Actions
- Use `ktlint -F .` in root folder to format Kotlin code
- Use SwiftLint for code formatting
- Always resolve formatting and analyzer errors before completing a task
- **CRITICAL**: Always run `ktlint -F .` after modifying any Kotlin files before committing

## Pigeon Code Generation
- Pigeon configuration is in `workmanager_platform_interface/pigeons/workmanager_api.dart`
- **MUST use melos to regenerate Pigeon files**: `melos run generate:pigeon`
- ⚠️ **DO NOT** run pigeon directly - always use the melos script for consistency
- Generated files:
  - Dart: `workmanager_platform_interface/lib/src/pigeon/workmanager_api.g.dart`
  - Kotlin: `workmanager_android/android/src/main/kotlin/dev/fluttercommunity/workmanager/pigeon/WorkmanagerApi.g.kt`
  - Swift: `workmanager_apple/ios/Classes/pigeon/WorkmanagerApi.g.swift`
- Do not manually edit generated files (*.g.* files)
- Generated files may have different formatting than dart format - this is expected and handled by exclusion patterns

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

## Testing Strategy & Preferences
- **Focus on business logic**: Test unique platform implementation logic, not Pigeon plumbing
- **Trust third-party components**: Consider Pigeon a trusted component - don't test its internals
- **Platform-specific behavior**: Test what makes each platform unique (Android WorkManager vs iOS BGTaskScheduler)
- **Avoid channel mocking**: Don't mock platform channels unless absolutely necessary
- **Test unsupported operations**: Verify platform-specific UnsupportedError throwing
- **Integration over unit**: Prefer integration tests for complete platform behavior validation

## Test Execution
- Run all tests: `flutter test` (from root or individual package)
- Android tests: `cd workmanager_android && flutter test`
- Apple tests: `cd workmanager_apple && flutter test`
- Native Android tests: `cd example/android && ./gradlew :workmanager_android:test`
- Native iOS tests: `cd example/ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'`
- Always build example app before completing: `cd example && flutter build apk --debug && flutter build ios --debug --no-codesign`

## Pigeon Migration Status
- ✅ Migration to Pigeon v22.7.4 completed successfully
- ✅ All platforms (Android, iOS) migrated from MethodChannel to Pigeon
- ✅ Unit tests refactored to focus on platform-specific business logic
- ✅ Code formatting and linting properly configured for generated files
- ✅ All tests passing: Dart unit tests, native Android tests, native iOS tests
- ✅ Example app builds successfully for both Android APK and iOS app

## Documentation Preferences
- Keep summaries concise - don't repeat completed tasks in status updates
- Focus on current progress and next steps
- Document decisions and architectural choices

## GitHub Actions - Package Analysis
- The `analysis.yml` workflow runs package analysis for all packages
- It performs `flutter analyze` and `dart pub publish --dry-run` for each package
- The dry-run validates that packages are ready for publishing
- Common issues that cause failures:
  - Uncommitted changes in git (packages should be published from clean state)
  - Files ignored by .gitignore but checked into git (use .pubignore if needed)
  - Modified files that haven't been committed
- Always ensure all changes are committed before pushing to avoid CI failures

## GitHub Actions - Formatting Issues
- The `format.yml` workflow runs formatting checks
- ❌ **Important Discovery**: `analysis_options.yml formatter.exclude` does NOT prevent `dart format` from formatting files
- ✅ **FIXED**: Updated CI workflow to use `find` command to exclude .g.dart files:
  ```bash
  find . -name "*.dart" ! -name "*.g.dart" ! -path "*/.*" -print0 | xargs -0 dart format --set-exit-if-changed
  ```
- **Root Issue**: `dart format` ignores analysis_options.yml exclusions and will always format ALL Dart files
- **Solution**: Filter files before passing to dart format to exclude generated files
- The `analysis_options.yml` exclusions only affect static analysis, not formatting