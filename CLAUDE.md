## Version Management
- **DO NOT manually edit CHANGELOG.md files** - Melos handles changelog generation automatically
- **Use semantic commit messages** for proper versioning:
  - `fix:` for bug fixes (patch version bump)
  - `feat:` for new features (minor version bump) 
  - `BREAKING CHANGE:` or `!` for breaking changes (major version bump)
  - Example: `fix: prevent iOS build errors with Logger availability`
- Melos will generate changelog entries from commit messages during release

## Pre-Commit Requirements
**CRITICAL**: Always run from project root before ANY commit:
1. `dart analyze` (check for code errors)
2. `ktlint -F .` (format Kotlin code)
3. `swiftlint --fix` (format Swift code)
4. `find . -name "*.dart" ! -name "*.g.dart" ! -path "*/.*" -print0 | xargs -0 dart format --set-exit-if-changed`
5. `flutter test` (all Dart tests)
6. `cd example/android && ./gradlew :workmanager_android:test` (Android native tests)
7. `cd example && flutter build apk --debug` (build Android example app)
8. `cd example && flutter build ios --debug --no-codesign` (build iOS example app)

## Code Generation
- Regenerate Pigeon files: `melos run generate:pigeon`
- Regenerate Dart files (including mocks): `melos run generate:dart`
- Do not manually edit *.g.* files
- Never manually modify mocks or generated files. Always modify the source, then run the generator tasks via melos.

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

## Changelog Guidelines
- **User-focused content only**: Write from end user perspective, not internal implementation details
- **No AI agent progress**: Don't document debugging steps, build fixes, or internal development process
- **What matters to users**: Breaking changes, new features, bug fixes that affect their code
- **Example of bad changelog entry**: "Fixed Kotlin null safety issues with androidx.work 2.10.2 type system improvements"
- **Example of good changelog entry**: "Fixed periodic tasks not respecting frequency changes"

## Documentation Components (docs.page)
- **Component reference**: https://use.docs.page/ contains the full reference for available components
- **Tabs component syntax**:
  ```jsx
  <Tabs>
    <TabItem label="Tab Name" value="unique-value">
      Content here
    </TabItem>
  </Tabs>
  ```
- Use `<TabItem>` not `<Tab>` - this is a common mistake that causes JavaScript errors
- Always include both `label` and `value` props on TabItem components

## Pull Request Description Guidelines

Template:
```markdown
## Summary
- Brief change description

Fixes #123

## Breaking Changes (if applicable)
**Before:** `old code`
**After:** `new code`
```