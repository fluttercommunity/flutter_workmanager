## Pre-Commit Requirements
**CRITICAL**: Always run from project root before ANY commit:
1. `ktlint -F .`
2. `find . -name "*.dart" ! -name "*.g.dart" ! -path "*/.*" -print0 | xargs -0 dart format --set-exit-if-changed`
3. `flutter test` (all Dart tests)
4. `cd example/android && ./gradlew :workmanager_android:test` (Android native tests)

## Code Generation
- Regenerate Pigeon files: `melos run generate:pigeon`
- Regenerate Dart files (including mocks): `melos run generate:dart`
- Do not manually edit *.g.* files

## Running Tests
- Use melos to run all tests: `melos run test`
- Or run tests in individual packages:
  - `cd workmanager_android && flutter test`
  - `cd workmanager_apple && flutter test`
  - `cd workmanager && flutter test`
- Before running tests in workmanager package, ensure mocks are up-to-date: `melos run generate:dart`

## Test Quality Requirements
- **NEVER create useless tests**: No `assert(true)`, `expect(true, true)`, or compilation-only tests
- **Test real logic**: Exercise actual methods with real inputs and verify meaningful outputs
- **Test edge cases**: null inputs, error conditions, boundary values

## Complex Component Testing
- **BackgroundWorker**: Cannot be unit tested due to Flutter engine dependencies - use integration tests