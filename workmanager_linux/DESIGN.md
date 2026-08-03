# Design notes

This document records the decisions behind `workmanager_linux` (2026-08-03).

## Goal

Implement the workmanager contract — "execute a Dart callback in the
background even when the app is closed" — on Linux, as honestly and testably
as possible, as a PR the maintainer can run and review. Linux has a real OS
scheduler (unlike the web), so this is a real implementation, not an
approximation: systemd *user* units.

## Chosen strategy: systemd user units + headless `--background-task` mode

The design doc (`docs/desktop-support.mdx`) compared systemd user units with
a self-daemonizing Dart isolate and chose systemd for v1: it is OS-native,
survives crashes, and provides catch-up semantics out of the box.

- **One-off tasks** → transient units via
  `systemd-run --user --unit=workmanager-<hash> --on-active=<delay>`.
  `--no-block` + no timer trigger for immediate runs. `--collect` unloads the
  transient units after completion (even on failure), so failed one-off runs
  don't linger as failed units.
- **Periodic tasks** → a `.timer`/`.service` pair in
  `~/.config/systemd/user/`:
  - `OnUnitActiveSec=<frequency>` — re-fires this long after the previous run.
  - `OnStartupSec=<initialDelay>` — one-shot first-fire offset (exact
    initialDelay semantics for free, since systemd timers fire when *any*
    directive elapses).
  - `Persistent=true` — WorkManager-style catch-up of runs missed while the
    system was off.
  - `Type=oneshot` service — the unit completes when the app process exits,
    so a failing task shows up as a failed unit in the journal.
- **Execution** → the unit runs the app binary
  (`Platform.resolvedExecutable` embedded at registration time) with
  `--background-task <taskName> --payload <path>`. The app's `main()` calls
  `WorkmanagerLinux.maybeRunBackgroundTask(args, callbackDispatcher)` which
  detects the invocation, runs the dispatcher, invokes the handler and exits
  with `0`/`1`.

## Why pure Dart with an injectable process runner

No Pigeon and no native plugin: everything is `systemctl --user` /
`systemd-run --user` invocations plus unit files. All external effects flow
through a `ProcessRunner` abstraction (defaulting to `Process.run`), and the
units/payload directories are constructor-injectable, so the whole suite is
pure Dart unit tests that never touch systemd.

## Deterministic naming instead of a registry

systemd unit names only allow `[a-zA-Z0-9:_.\-]` and unique names are
user-controlled. Instead of storing a registry, every unit name and payload
path derives from a stable 32-bit FNV-1a hash of the `uniqueName`
(`workmanager-<hash>.timer/.service`, payload
`$XDG_DATA_HOME/workmanager/payloads/workmanager-<hash>.json`). Registering,
querying (`is-active`), cancelling and listing all re-derive the same names
with no bookkeeping, and re-registering naturally replaces the previous
units.

## What is intentionally not implemented (v1)

- **Constraints** (network/battery/charging): accepted, ignored. The design
  doc's DBus/NetworkManager shims are real work; punted.
- **Backoff**: accepted, ignored. No retry semantics for failed one-off tasks
  in v1 (periodic tasks just wait for the next interval).
- **`existingWorkPolicy`**: effectively `REPLACE`; `KEEP` not implemented.
- **Tags / `cancelByTag`**: tags are accepted but not tracked, so
  `cancelByTag` throws `UnsupportedError`. A payload-side tag registry would
  make this implementable later.
- **iOS-only task types** (`registerProcessingTask`, health research,
  continued processing): `UnsupportedError`.
- **`workmanager` core parity details**: `printScheduledTasks` returns raw
  `systemctl list-timers` lines filtered to workmanager units.

## Headless dispatcher registration

The headless process runs the full Flutter engine, so the dispatcher *may*
use Flutter plugins — unlike the web worker bundle. But it must register via
`WorkmanagerLinux.executeTask` (a `WorkmanagerExecution`-style registry,
mirroring `workmanager_web`'s `execution.dart`) instead of
`Workmanager().executeTask`: the latter awaits a platform-channel handshake
(`backgroundChannelInitialized`) that has no native counterpart on Linux and
would hang/throw in a headless process.

## Known follow-ups

- Migrate to the `BackgroundTaskResult` enum with #712 (this package and
  `workmanager_web` implement the current `Future<bool>` API).
- `workmanager/test/backward_compatibility_test.dart` still expects a
  placeholder (`UnimplementedError`) on Linux hosts; once the Windows port
  lands too, that expectation should be updated.
- CI wiring for `dart test` in `workmanager_linux` (a melos test script
  entry or a GitHub Actions job).
