# workmanager_windows

Windows implementation of `workmanager` for Flutter, backed by **Task
Scheduler**. It registers one-off and periodic tasks as per-user scheduled
tasks via the `schtasks` command line; when a task fires, Windows launches
your app executable with a `--background-task <taskName>` argument, the app
runs the registered callback handler headless and exits.

> ⚠️ **EXPERIMENTAL.** Read [Honest limitations](#honest-limitations) before
> using this package. v1 uses the `schtasks` CLI only — no COM, no native
> code and no `win32` dependency — and is pure Dart.

## How it works

| Situation | Mechanism |
|---|---|
| One-off task | `schtasks /Create /SC ONCE` — runs once at `now + initialDelay` (minute granularity). |
| Periodic task | `schtasks /Create /SC DAILY /RI <minutes>` — repeats every `frequency` (clamped to ≥ 1 minute, ≤ 416 days). |
| Input data | Persisted as a JSON file in `%LOCALAPPDATA%\workmanager_windows\payloads\<uniqueName>.json` and passed to the headless process via `--payload-file`. |
| Execution | Task Scheduler launches `<app.exe> --background-task <taskName> [--payload-file <path>]`; the app runs the registered handler and exits with `0`/`1`. |
| Cancellation | `schtasks /End` (running instance) + `schtasks /Delete` + payload cleanup. |

## Setup

### 1. Add the dependency

```yaml
dependencies:
  workmanager_windows: ^0.0.1
```

### 2. Make `main()` headless-aware

```dart
import 'package:workmanager/workmanager.dart';
import 'package:workmanager_windows/workmanager_windows.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  WorkmanagerWindows().executeTask((taskName, inputData) async {
    // Do your background work here. The full Flutter engine is available,
    // but no window is shown.
    return true;
  });
}

void main(List<String> args) {
  if (WorkmanagerWindows.maybeRunBackgroundTask(args, callbackDispatcher)) {
    return;
  }
  Workmanager().initialize(callbackDispatcher);
  runApp(const MyApp());
}
```

### 3. Register tasks as usual

```dart
final workmanager = Workmanager();
await workmanager.registerOneOffTask(
  'unique-name',
  'taskName',
  inputData: {'key': 'value'},
  initialDelay: const Duration(minutes: 5),
);
await workmanager.registerPeriodicTask(
  'unique-name',
  'taskName',
  frequency: const Duration(minutes: 30),
);
```

## API

- `registerOneOffTask(...)` / `registerPeriodicTask(...)` — same signatures as
  `Workmanager()`
- `cancelByUniqueName(...)` / `cancelAll()`
- `isScheduledByUniqueName(...)`
- `printScheduledTasks()` — JSON list of the plugin's scheduled tasks
- `maybeRunBackgroundTask(args, callbackDispatcher)` — headless entry point
- `WorkmanagerWindows().executeTask(handler)` — registers the handler inside
  the callback dispatcher

iOS-only task types (`registerProcessingTask`, `registerHealthResearchTask`,
`registerContinuedProcessingTask`) and `cancelByTag` throw
`UnsupportedError`.

## Honest limitations

- **Per-user tasks.** Task Scheduler tasks run as the user who registered
  them, only while that user is logged on. "Run whether the user is logged on
  or not" requires elevated privileges (`schtasks /Create /RU ... /RP ...` or
  `SYSTEM`) — not exposed in v1; an admin can enable it for a task manually.
- **Minute granularity.** The scheduler has no sub-minute precision; a zero
  `initialDelay` is rounded up to the next minute so one-off tasks still run.
- **Locale-sensitive CLI.** `schtasks` parses dates with the system regional
  format; v1 emits `MM/DD/YYYY` and assumes an English (en-US) regional
  setting.
- **Constraints/backoff are accepted but ignored** (no-ops): Task Scheduler
  does not expose `WakeToRun`, battery/AC, idle or network conditions through
  the `schtasks` CLI. Re-registering a `uniqueName` always replaces the task
  (`existingWorkPolicy` is not honored).
- No equivalent of WorkManager's guaranteed-while-app-killed semantics beyond
  the registered task itself, and no sub-minute or exact-time guarantees.
- `printScheduledTasks` parses `/Query /FO CSV` output and assumes the
  standard three columns (TaskName, Next Run Time, Status).

See [`docs/windows.mdx`](../docs/windows.mdx) for the full documentation.

## Structure

```
lib/
  workmanager_windows.dart  # WorkmanagerWindows (WorkmanagerPlatform impl)
  execution.dart            # Flutter-free handler registry + headless runner
  src/
    process_runner.dart     # injectable ProcessRunner (schtasks invocation)
    schtasks.dart           # schtasks command-line builder (unit-tested)
    payload_store.dart      # on-disk JSON payload persistence
```

The `ProcessRunner` is injectable, so the whole package is unit-testable on
any host without Windows.
