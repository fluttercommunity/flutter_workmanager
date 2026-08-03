# workmanager_linux

Experimental Linux implementation of `workmanager` for Flutter, backed by
**systemd user units**. Unlike the web, Linux has a real OS scheduler, so the
plugin contract — "execute Dart code in the background, even when the app is
closed" — is implemented with actual systemd timers, not an approximation.

> ⚠️ **EXPERIMENTAL.** Read [Honest limitations](#honest-limitations) before
> using this package. Requires a systemd user session; Flatpak/Snap sandboxing
> is not supported yet.

## How it works

| Task type | Mechanism |
|---|---|
| One-off | Transient units via `systemd-run --user --unit=workmanager-<hash> --on-active=<delay>` (or `--no-block` for immediate runs). Transient units vanish after the task ran. |
| Periodic | A `.timer`/`.service` unit pair in `~/.config/systemd/user/`. The timer uses `OnUnitActiveSec` for the frequency and `Persistent=true` for WorkManager-style catch-up of runs missed while the system was off. |

The service/timer launches your app binary in **headless mode** with
`--background-task <taskName> --payload <path>`. The payload is the
`inputData` JSON persisted at registration time (Android-style on-disk
payload) under `$XDG_DATA_HOME/workmanager/payloads/`.

There is no native code and no Pigeon: the package is pure Dart that shells
out to `systemctl --user` / `systemd-run --user` through an injectable
process runner (so all tests run without systemd).

## Setup

### 1. Requirements

- A systemd-based Linux distribution with a **user session**.
- The user session must be able to reach the systemd user manager. When the
  app is launched from a normal desktop session this just works; for
  headless/autostart contexts run `loginctl enable-linger $USER` so user
  units keep running after logout (see the caveat below).
- Flatpak and Snap sandboxes cannot write user units — punted for v1.

### 2. Add the dependency

```yaml
dependencies:
  workmanager: ^0.10.0
  workmanager_linux: ^0.1.0
```

The main `workmanager` package delegates to this package on Linux
automatically, so `Workmanager()` works out of the box. Registering with the
main package API is all you need for scheduling:

```dart
Workmanager().initialize(callbackDispatcher);
Workmanager().registerOneOffTask("task-id", "sync", initialDelay: Duration(minutes: 5));
Workmanager().registerPeriodicTask("periodic-id", "sync", frequency: Duration(hours: 1));
```

### 3. Headless `main()`

Your `main()` must detect the `--background-task` invocation and run the
callback instead of starting the UI:

```dart
Future<void> main(List<String> args) async {
  if (await WorkmanagerLinux.maybeRunBackgroundTask(args, callbackDispatcher)) {
    // The process was launched headless by systemd to run a background task.
    // The result was logged and the process already exited (0 = success).
    return;
  }
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  // Register with WorkmanagerLinux.executeTask — not Workmanager().executeTask —
  // because the headless process has no native platform-channel counterpart.
  WorkmanagerLinux.executeTask((taskName, inputData) async {
    print("Background task: $taskName");
    // Your background work here. Flutter plugins are allowed.
    return true;
  });
}
```

The dispatcher's exit code is the task result: `0` on success, `1` on failure
or when no handler was registered — so failed runs show up as failed units in
`journalctl --user`.

## Honest limitations

- **Constraints are accepted but ignored** (`networkType`, `requiresCharging`,
  ...). No battery/AC/network gating in v1.
- **Backoff policy is accepted but ignored** — failed one-off tasks are not
  retried. A failed periodic task simply waits for the next interval.
- **`existingWorkPolicy` is effectively `REPLACE`**: re-registering a unique
  name overwrites the units (the previous timer is replaced). `KEEP` is not
  implemented.
- **Tags are accepted but not tracked**, so `cancelByTag` throws
  `UnsupportedError` (a tag registry is needed; cancel by unique name or use
  `cancelAll` instead).
- **Frequency is honored as-is** (no Android-style 15-minute floor; systemd
  supports arbitrary intervals). Frequencies below 1 minute are not useful in
  practice — systemd resolves `OnUnitActiveSec` to whole seconds.
- **User timers stop while the user is logged out** unless
  `loginctl enable-linger $USER` is set. On many desktops, systemd user
  services also only run after the first graphical login of that user.
- `registerProcessingTask`, `registerHealthResearchTask`,
  `registerContinuedProcessingTask` throw `UnsupportedError` (iOS-only task
  types).
- Flatpak/Snap sandboxing is unsupported (no way to write user units).

## Testing

The package is pure Dart with an injectable process runner — the test suite
asserts the exact `systemctl`/`systemd-run` commands, unit file contents,
payload round-trips and the headless argument parsing, and runs anywhere
without systemd:

```bash
cd workmanager_linux
dart test
```

## Design

See [DESIGN.md](DESIGN.md) for the decisions behind the systemd-based
approach.
