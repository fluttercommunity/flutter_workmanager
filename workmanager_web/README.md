# workmanager_web

Experimental web implementation of `workmanager` for Flutter. It approximates
"execute Dart code in the background, even when the app is closed" on the web
using a **Service Worker** (for page-closed execution) and a **Web Worker**
(for real parallel execution while the page is open).

> ⚠️ **EXPERIMENTAL.** Read [Honest limitations](#honest-limitations) before
> using this package. Web browsers cannot run Dart at an exact wall-clock time
> after the page is closed — the web contract is a best-effort approximation.

## How it works

| Situation | Mechanism |
|---|---|
| Page open | Tasks execute in a dedicated **Web Worker** running the compiled callback dispatcher (dart2js, Flutter-free) — real parallel execution off the main thread. Falls back to in-page execution if the bundle is missing. |
| Page closed — Periodic Background Sync | Chromium fires the Service Worker roughly every `minInterval` (browser minimum **12 hours**) once the PWA is installed and the user has engagement. The Service Worker then runs the **compiled Dart dispatcher itself** via `importScripts` and records the result in IndexedDB. |
| Page closed — Web Push | A push message wakes the Service Worker and triggers the same Dart execution path. Requires a push server. |
| Page closed — fetch interception | Opportunistic: a same-origin request can wake the Service Worker and run due periodic tasks / overdue one-off tasks. Not reliable — browsers throttle Service Worker wake-ups. |

Recorded results are replayed into the app's event log on the next page load,
so background executions while the page was closed are observable.

## Setup

### 1. Add the dependency

```yaml
dependencies:
  workmanager_web: ^0.1.0
```

The main `workmanager` package also delegates to this package on web, so
`Workmanager()` works on web too. For web-specific options use
`WorkmanagerWeb` directly.

### 2. Copy the Service Worker into your app

The Service Worker script is JavaScript and lives in this package's `web/`
folder. Copy it into your app's `web/` folder so it is served at
`/workmanager_service_worker.js`:

```bash
cp ../workmanager_web/web/workmanager_service_worker.js web/
```

### 3. Write a Flutter-free dispatcher and compile it

A Service Worker cannot run the Flutter engine, so your callback dispatcher
must live in a **Flutter-free Dart file** (no `package:flutter/...` imports)
and be compiled with plain dart2js. Use `WorkmanagerExecution.executeTask`
instead of `Workmanager().executeTask(...)`:

```dart
// lib/background_tasks.dart — pure Dart, no Flutter imports
import 'package:workmanager_web/execution.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  WorkmanagerExecution.instance.executeTask((taskName, inputData) async {
    // Flutter-free background work only.
    return true;
  });
}
```

```dart
// web/background.dart — standalone dart2js entrypoint
import 'package:workmanager_web/worker.dart';
import 'package:my_app/background_tasks.dart';

void main() {
  WorkmanagerWebWorker.run(callbackDispatcher);
}
```

Compile it and commit the output next to your app's `web/` folder:

```bash
dart compile js --no-source-maps -O2 web/background.dart -o web/background.dart.js
```

> **Why `-Ddart.library.js_interop=false` was evaluated and rejected:** that
> define selects the legacy inline JS interop for dart2wasm. dart2js supports
> `dart:js_interop` natively and the define would actually break this package's
> conditional imports. Plain `dart compile js` is what you want.

### 4. Initialize and register tasks

```dart
import 'package:workmanager_web/workmanager_web.dart';

await WorkmanagerWeb().initialize(
  callbackDispatcher,
  dispatcherUrl: WorkmanagerWeb.defaultDispatcherUrl, // /background.dart.js
);

await WorkmanagerWeb().registerPeriodicTask(
  'uniqueName',
  'taskName',
  frequency: const Duration(minutes: 15),
);
```

The example app in this repository wires all of this up — see
[`example/`](../../example) and its `web/` folder for a runnable reference,
including the PWA manifest.

### 5. Communicating with the background worker

Task execution is request/response — the page asks the worker to run a task and
gets the result back. For anything more interactive (progress updates, live
data, "worker, do X now"), the worker also supports free-form two-way
messaging over `postMessage`:

```dart
// Page side — send a message, listen for replies.
WorkmanagerWeb().workerMessages.listen((payload) {
  print('worker says: $payload');
});
WorkmanagerWeb().sendMessageToWorker({'op': 'watch', 'ticker': 'btc'});
```

```dart
// Dispatcher side (Flutter-free bundle) — receive and reply.
void callbackDispatcher() {
  WorkmanagerExecution.instance.executeTask((taskName, inputData) async {
    return true;
  });
  WorkmanagerExecution.instance.messageHandler = (payload) {
    WorkmanagerExecution.instance.sendToPage?.call({'kind': 'ack'});
  };
}
```

How it maps to the browser:

- **Page open** — messages travel between the page and the dedicated Web
  Worker over `postMessage`, so the handler runs off the main thread.
- **No Web Worker available** — the message is delivered directly to the
  in-page dispatcher; replies surface on the same `workerMessages` stream.
- **Service Worker execution (page closed)** — a `sendToPage` call is
  delivered to every open page via `clients.postMessage`; when no page is
  open it is dropped (persistent task results still arrive through
  `backgroundEvents` on the next load).

The example app demonstrates this with a live "worker chat" panel and a
simulated price-watch use case.

## Testing it (what the maintainers verified)

1. `flutter run -d chrome` (or `flutter build web` + serve over HTTPS or
   `localhost`).
2. **Install the PWA** (Chrome address bar icon, or the in-app "Install PWA"
   button) and interact with the app for a bit — Periodic Background Sync only
   runs for installed, engaged PWAs.
3. Register a periodic task, then open DevTools → **Application** →
   **Periodic Background Sync** and press **periodicsync** for the task's tag.
   This works even with a 15-minute frequency because Chrome's 12-hour minimum
   only applies to the real scheduler, not the DevTools trigger.
4. Close the page, trigger **periodicsync** again, reopen the app: the event
   log shows the task executed **inside the Service Worker** (compiled Dart
   dispatcher), replayed from IndexedDB.
5. Web Push: DevTools → Application → Service Workers → **Push**, or send a
   real push from your server. The push payload may contain
   `{"taskName": "...", "inputData": {...}, "title": "..."}`.

## Honest limitations

- **No exact scheduling.** There is no web API for "run this at 15:00".
  `registerPeriodicTask(frequency)` maps to Periodic Background Sync, which
  Chrome runs roughly every `max(frequency, 12h)` *only for installed,
  engaged PWAs*. `registerOneOffTask(initialDelay)` runs on a page timer while
  the page is open, and best-effort on the next Service Worker wake after the
  deadline when it is closed.
- **Chromium only** for Periodic Background Sync (Safari/Firefox do not
  implement it). In-page Web Worker execution works everywhere.
- **Secure context required**: HTTPS or `localhost` (service workers,
  periodic sync and push are all gated on this).
- **The callback dispatcher must be Flutter-free** to run inside the Service
  Worker / Web Worker. Flutter plugins and UI code cannot run there; only the
  code reachable from your Flutter-free dispatcher file is compiled into the
  bundle.
- **No notification on missed work.** If the browser never wakes the Service
  Worker, a task is simply recorded as missed on the next open.
- **One-off tasks are best-effort** when the page is closed: they run on the
  next wake event (periodic sync, push, fetch) after their deadline, which may
  be much later — or never if no wake happens.
- **Experimental**: the API and file layout may change. Do not rely on it for
  production workloads yet.

## API

`WorkmanagerWeb` mirrors the main package's ergonomics:

- `initialize(callbackDispatcher, {serviceWorkerUrl, dispatcherUrl, useWebWorker})`
- `registerOneOffTask(...)` / `registerPeriodicTask(...)` — same signatures as
  `Workmanager()`
- `executeTask(handler)` — used inside the dispatcher (also available as
  `WorkmanagerExecution.instance.executeTask(...)` in the compiled bundle)
- `cancelByUniqueName(...)` / `cancelByTag(...)` / `cancelAll()`
- `isScheduledByUniqueName(...)` / `printScheduledTasks()`
- `triggerTask(...)` — run a task now (demos/tests)
- `backgroundEvents` — live stream of execution events, including events
  replayed from the Service Worker
- `sendMessageToWorker(payload)` / `workerMessages` — free-form two-way
  messaging with the background worker (see "Communicating with the
  background worker")

iOS-only task types (`registerProcessingTask`, `registerHealthResearchTask`,
`registerContinuedProcessingTask`) throw `UnsupportedError` on web.

## Structure

```
lib/
  workmanager_web.dart      # WorkmanagerWeb (WorkmanagerPlatform impl)
  execution.dart            # Flutter-free handler registry (used by the bundle)
  worker.dart               # WorkmanagerWebWorker — bundle entrypoint
  src/
    worker_protocol.dart    # page <-> worker message contract incl. chat messages (unit-tested)
    browser_glue_*.dart     # js_interop bindings (web) + VM-safe stubs
web/
  workmanager_service_worker.js   # the Service Worker (copy into your app)
```

See [DESIGN.md](DESIGN.md) for the design decisions and alternatives
considered.
