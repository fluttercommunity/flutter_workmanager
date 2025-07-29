# Contributing to Flutter Workmanager

Thank you for your interest in contributing to Flutter Workmanager! This guide will help you get started.

## Development Setup

### Prerequisites
- Flutter SDK (latest stable version)
- Android Studio / Xcode for platform-specific development
- Melos for monorepo management

### Getting Started

1. Fork and clone the repository
2. Install melos globally: `dart pub global activate melos`
3. Bootstrap the workspace: `melos bootstrap`
4. Run tests: `melos run test`

## Project Structure

This is a federated plugin with the following packages:
- `workmanager/` - Main plugin package
- `workmanager_android/` - Android implementation
- `workmanager_apple/` - iOS/macOS implementation  
- `workmanager_platform_interface/` - Shared interface
- `example/` - Demo application

## Development Workflow

### Making Changes

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Make your changes
3. Run formatting: `melos run format`
4. Run analysis: `melos run analyze` 
5. Run tests: `melos run test`
6. Test on example app: `cd example && flutter run`

### Code Generation

If you modify the Pigeon API definition in `workmanager_platform_interface/pigeons/workmanager_api.dart`:

```bash
# Regenerate Pigeon files
melos run generate:pigeon
```

**Important**: Never manually edit generated `*.g.*` files.

### Code Formatting

The project uses specific formatting rules:

- **Dart**: Use `dart format` (configured to exclude generated files)
- **Kotlin**: Use `ktlint -F .` in root folder  
- **Swift**: Use SwiftLint for formatting

Generated files are automatically excluded from formatting checks.

## Testing

### Running Tests

```bash
# All tests
melos run test

# Specific package tests
cd workmanager_android && flutter test
cd workmanager_apple && flutter test

# Native tests
cd example/android && ./gradlew :workmanager_android:test
cd example/ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner
```

### Integration Tests

```bash
# iOS integration tests
melos run test:drive_ios

# Android integration tests  
melos run test:drive_android
```

### Example App Testing

Always build the example app before completing your changes:

```bash
cd example
flutter build apk --debug
flutter build ios --debug --no-codesign
```

## Platform-Specific Guidelines

### Android
- Follow Android WorkManager best practices
- Test on various Android API levels
- Ensure background task constraints work properly

### iOS
- Test both Background Fetch and BGTaskScheduler APIs
- Verify 30-second execution limits are respected
- Test on physical devices (background tasks don't work in simulator)

## Publishing (Maintainers Only)

### Pre-publish Checklist

Before publishing any package, run the dry-run validation:

```bash
# Validate all packages are ready for publishing
melos run publish:dry-run

# Or for individual packages:
cd workmanager && dart pub publish --dry-run
cd workmanager_android && dart pub publish --dry-run  
cd workmanager_apple && dart pub publish --dry-run
cd workmanager_platform_interface && dart pub publish --dry-run
```

This validates that:
- All dependencies are correctly specified
- No uncommitted changes exist
- Package follows pub.dev guidelines
- All required files are included

### Version Management

Use melos for coordinated version bumps:

```bash
# Bump versions across related packages
melos version
```

### Publishing Process

1. Ensure all tests pass: `melos run test`
2. Run dry-run validation: `melos run publish:dry-run`
3. Update CHANGELOGs for all modified packages
4. Create release PR with version bumps
5. After merge, tag release: `git tag v0.x.x`
6. Publish packages: `melos publish --no-dry-run`

## Documentation

### Updating Documentation

- **API docs**: Documented inline in Dart code
- **User guides**: Located in `docs/` directory using docs.page
- **Setup guides**: Integrated into quickstart documentation

### Documentation Structure

- `docs/index.mdx` - Overview and features
- `docs/quickstart.mdx` - Installation and basic setup
- `docs/customization.mdx` - Advanced configuration
- `docs/debugging.mdx` - Troubleshooting guide

### Testing Documentation

Test documentation changes locally:
1. Push changes to a branch
2. View at: `https://docs.page/fluttercommunity/flutter_workmanager~your-branch`

## GitHub Actions

The project uses several CI workflows:

- **Format** (`.github/workflows/format.yml`): Code formatting checks
- **Analysis** (`.github/workflows/analysis.yml`): Package analysis and dry-run validation  
- **Test** (`.github/workflows/test.yml`): Unit tests, native tests, integration tests

All checks must pass before merging PRs.

## Common Issues

### Generated Files

If you see formatting or analysis errors in generated files:
- Never manually edit `*.g.*` files
- Use `melos run generate:pigeon` to regenerate
- Generated files are excluded from formatting by design

### CI Failures

**Package analysis failures**: Usually caused by uncommitted changes or missing dependencies
**Format failures**: Run `melos run format` locally first
**Test failures**: Ensure all tests pass locally with `melos run test`

## Getting Help

- **Bug reports**: [GitHub Issues](https://github.com/fluttercommunity/flutter_workmanager/issues)
- **Questions**: [GitHub Discussions](https://github.com/fluttercommunity/flutter_workmanager/discussions)
- **Documentation**: [docs.page](https://docs.page/fluttercommunity/flutter_workmanager)

## Code of Conduct

This project follows the [Flutter Community Code of Conduct](https://github.com/fluttercommunity/community/blob/main/CODE_OF_CONDUCT.md).

## License

By contributing to Flutter Workmanager, you agree that your contributions will be licensed under the [MIT License](LICENSE).