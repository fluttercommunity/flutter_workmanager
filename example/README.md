# Flutter Workmanager Example

Complete working demo showing all Flutter Workmanager features and task types.

## Features Demonstrated

- **One-off tasks**: Immediate background execution
- **Periodic tasks**: Scheduled recurring background work
- **Processing tasks**: Long-running iOS background tasks
- **Task constraints**: Network, battery, and device state requirements
- **Debug notifications**: Visual feedback when tasks execute
- **Error handling**: Proper task success/failure/retry logic
- **Platform differences**: Android vs iOS background execution

## Quick Start

1. **Clone and run**:
   ```bash
   git clone https://github.com/fluttercommunity/flutter_workmanager.git
   cd flutter_workmanager/example
   flutter run
   ```

2. **Platform setup**:
   - **Android**: Works immediately ✅
   - **iOS**: Follow the iOS setup in `ios/Runner/AppDelegate.swift` and `ios/Runner/Info.plist`

3. **Test background tasks**:
   - Tap buttons to schedule different task types
   - Put app in background to see tasks execute
   - Check debug notifications to verify execution

## Example Tasks

The demo includes practical examples:

- **Simulated API sync**: Fetches data and stores locally
- **File cleanup**: Removes old cached files
- **Periodic maintenance**: Regular app maintenance tasks
- **Long processing**: iOS-specific long-running tasks

## Key Files

- `lib/main.dart` - Main app with task scheduling UI
- `lib/callback_dispatcher.dart` - Background task execution logic
- `ios/Runner/AppDelegate.swift` - iOS background task registration
- `ios/Runner/Info.plist` - iOS background modes configuration

## Testing Background Tasks

**Android**: 
- Tasks run reliably in background
- Enable debug mode to see notifications
- Use `adb shell dumpsys jobscheduler` to inspect scheduled tasks

**iOS**: 
- Test on physical device (not simulator)
- Enable Background App Refresh in Settings
- Use Xcode debugger commands to trigger tasks immediately

## Documentation

For detailed guides and real-world use cases, visit: **[docs.page/fluttercommunity/flutter_workmanager →](https://docs.page/fluttercommunity/flutter_workmanager)**
