# Swift Package Manager Migration Plan

## Overview
Migrate `workmanager_apple` plugin to support Swift Package Manager (SPM) while maintaining full CocoaPods backward compatibility.

## Current Structure Analysis
```
workmanager_apple/ios/
├── Assets/
├── Classes/
│   ├── BackgroundTaskOperation.swift
│   ├── BackgroundWorker.swift
│   ├── Extensions.swift
│   ├── LoggingDebugHandler.swift
│   ├── NotificationDebugHandler.swift
│   ├── SimpleLogger.swift
│   ├── ThumbnailGenerator.swift
│   ├── UserDefaultsHelper.swift
│   ├── WMPError.swift
│   ├── WorkmanagerDebugHandler.swift
│   ├── WorkmanagerPlugin.swift
│   └── pigeon/
│       └── WorkmanagerApi.g.swift
├── Resources/
│   └── PrivacyInfo.xcprivacy
└── workmanager_apple.podspec
```

## Migration Strategy

### Phase 1: SPM Structure Setup
1. Create `workmanager_apple/ios/Package.swift`
2. Create new directory structure:
   ```
   workmanager_apple/ios/
   ├── Sources/
   │   └── workmanager_apple/
   │       ├── include/
   │       │   └── workmanager_apple-umbrella.h (if needed)
   │       └── [all .swift files moved here]
   └── Resources/
       └── PrivacyInfo.xcprivacy
   ```

### Phase 2: File Migration
- **Move Swift files** from `Classes/` to `Sources/workmanager_apple/`
- **Preserve pigeon structure** as `Sources/workmanager_apple/pigeon/`
- **Update import statements** if needed
- **Handle resources** - PrivacyInfo.xcprivacy

### Phase 3: Configuration Files
- **Create Package.swift** with proper target definitions
- **Update podspec** to reference new file locations
- **Maintain backward compatibility** for CocoaPods users

### Phase 4: Testing Strategy
- **Dual build testing** in GitHub Actions
- **CocoaPods build**: Test existing workflow
- **SPM build**: New workflow for SPM validation
- **Example app testing**: Both dependency managers

## Implementation Details

### Package.swift Configuration
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "workmanager_apple",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "workmanager_apple", targets: ["workmanager_apple"])
    ],
    targets: [
        .target(
            name: "workmanager_apple",
            resources: [.process("Resources")]
        )
    ]
)
```

### GitHub Actions Strategy

**Matrix Strategy using Flutter SPM configuration:**
- **CocoaPods Build**: `flutter config --no-enable-swift-package-manager` + build
- **SPM Build**: `flutter config --enable-swift-package-manager` + build

**Key Features:**
1. **Flutter-native approach**: Use `flutter config` flags to switch dependency managers
2. **Simple validation**: Does example app build and run with both configurations?
3. **Matrix builds**: Test both `--enable-swift-package-manager` and `--no-enable-swift-package-manager`

**GitHub Actions Matrix:**
```yaml
strategy:
  matrix:
    spm_enabled: [true, false]
    include:
      - spm_enabled: true
        config_cmd: "flutter config --enable-swift-package-manager"
        name: "SPM"
      - spm_enabled: false  
        config_cmd: "flutter config --no-enable-swift-package-manager"
        name: "CocoaPods"
```

## Risk Mitigation

### Backward Compatibility
- **Keep CocoaPods support** indefinitely
- **Update podspec paths** to point to new locations
- **Test both build systems** in CI

### File Organization
- **Maintain logical grouping** of Swift files
- **Preserve pigeon integration** with generated files
- **Handle resources properly** in both systems

### Dependencies
- **No external Swift dependencies** currently - simplifies migration
- **Flutter framework dependency** handled by both systems

## Testing Requirements

### Pre-Migration Tests
- [ ] Current CocoaPods build works
- [ ] Example app builds and runs
- [ ] All functionality works on physical device

### Verification Strategy
**Simple test**: Does the example app build and run with both dependency managers?

**CocoaPods Build:**
```bash
flutter config --no-enable-swift-package-manager
cd example && flutter build ios --debug --no-codesign
```

**SPM Build:**
```bash
flutter config --enable-swift-package-manager
cd example && flutter build ios --debug --no-codesign
```

**Flutter Requirements:**
- Flutter 3.24+ required for SPM support
- SPM is off by default, must be explicitly enabled

### CI/CD Integration
- Use Flutter's built-in SPM configuration flags
- Test both dependency managers via matrix builds
- No separate long-lived branches needed

## Implementation Phases

### Phase 1: Directory Restructure (First Commit)
1. Create SPM-compliant directory structure
2. Move all Swift files to `Sources/workmanager_apple/`
3. Update podspec to reference new locations
4. Ensure CocoaPods + Pigeon still work
5. **Verification**: Example app builds and runs with CocoaPods

### Phase 2: SPM Configuration (Second Commit)
1. Add `Package.swift` with proper configuration
2. Handle resources (PrivacyInfo.xcprivacy)
3. **Verification**: Example app builds and runs with SPM

### Phase 3: CI Integration (Third Commit)
1. Update GitHub Actions to test both dependency managers
2. Use Flutter config flags for SPM/CocoaPods selection

## Success Criteria
- ✅ SPM support working in Flutter projects
- ✅ Full CocoaPods backward compatibility maintained
- ✅ All existing functionality preserved
- ✅ CI/CD tests both dependency managers
- ✅ No breaking changes for existing users
- ✅ Proper resource and privacy manifest handling