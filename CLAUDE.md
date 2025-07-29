## Pre-Commit Requirements
**CRITICAL**: Always run from project root before ANY commit:
1. `ktlint -F .`
2. `find . -name "*.dart" ! -name "*.g.dart" ! -path "*/.*" -print0 | xargs -0 dart format --set-exit-if-changed`
3. `flutter test` (all Dart tests)
4. `cd example/android && ./gradlew :workmanager_android:test` (Android native tests)

## Code Generation
- Regenerate Pigeon files: `melos run generate:pigeon`
- Do not manually edit *.g.* files

## Test Quality Requirements
- **NEVER create useless tests**: No `assert(true)`, `expect(true, true)`, or compilation-only tests
- **Test real logic**: Exercise actual methods with real inputs and verify meaningful outputs
- **Test edge cases**: null inputs, error conditions, boundary values

## Complex Component Testing
- **BackgroundWorker**: Cannot be unit tested due to Flutter engine dependencies - use integration tests