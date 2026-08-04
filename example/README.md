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

## Web Demo (experimental)

Run `flutter run -d chrome` (or `flutter build web` and serve over HTTPS or
localhost) to get the web-only demo. It demonstrates the experimental
`workmanager_web` package with a simulated **weather watch** — no network
and no API keys needed:

- **Two-way worker messaging** — the page and the background worker talk
  over `postMessage` (Worker chat tab). Tap "Watch Cardiff" and the worker
  streams simulated temperatures, alerting when it drops below the
  threshold; type any text and it echoes back. Page → worker via
  `sendMessageToWorker()`, worker → page via `sendToPage()` (surfaced on
  `WorkmanagerWeb.workerMessages`).
- **Background tasks in a Web Worker** — register one-off / periodic tasks
  and watch them execute off the main thread (the UI stays responsive while
  the task's CPU loop runs). "Run check now" fires a one-off task; a
  periodic temperature check is registered automatically every 15 minutes.
  Results appear in the Task log tab.
- **Service Worker execution** — install the PWA, trigger Periodic Background
  Sync from DevTools, close the page, trigger it again and reopen: the task
  ran inside the Service Worker (compiled Dart dispatcher) and the result is
  replayed from IndexedDB into the event log.

The background handler lives in `lib/web/background_tasks.dart` — a
Flutter-free file compiled with plain `dart compile js` into
`web/background.dart.js` (see `tool/build_web_background.sh`). Temperatures
are simulated so the demo works offline; swap `_simulatedTemp()` for a real
fetch to see the same pattern with live data.

## Key Files

- `lib/main.dart` - Main app with task scheduling UI
- `lib/web/` - Web-only demo (Flutter-free dispatcher, worker chat, PWA install glue)
- `lib/callback_dispatcher.dart` - Background task execution logic
- `ios/Runner/AppDelegate.swift` - iOS background task registration
- `ios/Runner/Info.plist` - iOS background modes configuration
