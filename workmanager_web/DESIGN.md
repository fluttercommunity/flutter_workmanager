# Design notes

This document records the decisions behind `workmanager_web` (2026-08-02).

## Goal

Approximate the workmanager contract — "execute a Dart callback in the
background even when the app is closed" — on the web, as honestly and
testably as possible, as a PR the maintainer can run and review.

## Chosen strategy: hybrid (compiled Dart bundle + JS bridge)

The task laid out two viable paths for page-closed execution:

1. Compile the user's `callbackDispatcher` to a standalone dart2js bundle and
   load it in the Service Worker via `importScripts`.
2. JS-bridge: the Service Worker triggers → posts to open clients → the page
   runs the Dart callback; if no client is open, a minimal JS fallback records
   the event for the next open.

We chose a **hybrid**, with the compiled-Dart-in-Service-Worker path as the
centerpiece:

- **In-page**: a dedicated Web Worker runs the compiled dispatcher bundle
  (real parallel execution). If the bundle is missing, execution falls back to
  the page isolate.
- **Page closed**: Periodic Background Sync, Web Push and (opportunistically)
  fetch interception wake the Service Worker, which runs the *same* compiled
  Dart dispatcher bundle directly in its global scope and records the outcome
  in IndexedDB. Results replay into the app on the next load.
- **Page open but SW woken**: the Service Worker relays the task to open
  clients, so the callback runs with the full Dart runtime on the page.

Why this beats pure path 2: the owner gets a real end-to-end demo where the
user's actual Dart callback executes with no page open — the closest honest
version of the plugin contract. The JS bridge is still present as the relay
and as the graceful-degradation fallback when the bundle cannot load.

## Constraints discovered while building

- **`importScripts` is only legal during top-level Service Worker script
  execution** (Chrome 71+, enforced by the spec). Lazy `importScripts` inside
  `periodicsync`/`push` handlers throws. Therefore the dispatcher bundle URL
  is passed to the Service Worker at registration time as a query parameter
  (`/workmanager_service_worker.js?dispatcherUrl=...`), and the bundle is
  imported synchronously at startup, wrapped in `try/catch` so relay-only mode
  still works when the bundle is absent.
- **dart2js cannot expose async functions with `toJS`** in current SDKs
  (compile-time error). The bundle therefore exposes a callback-style
  `self.__wmTrigger(taskName, inputData, onDone)`; the Service Worker wraps it
  in a `Promise` (`wmCallDispatcher`).
- **A Dart isolate cannot run inside a Service Worker**, and neither can the
  Flutter engine. The dispatcher must live in a Flutter-free Dart file
  (`package:flutter` imports are not allowed there) and is compiled with plain
  `dart compile js`. Flutter-free handlers can use `dart:async`/`dart:convert`
  etc., but not Flutter plugins.
- **`-Ddart.library.js_interop=false` was evaluated and rejected**: it targets
  dart2wasm's legacy inline interop. dart2js supports `dart:js_interop`
  natively, and the define would disable the package's own conditional imports
  (`if (dart.library.js_interop)`), breaking the build.
- **`dart:js_interop` and `flutter_web_plugins` are not importable on the VM**,
  so the package uses conditional imports with VM-safe stubs
  (`browser_glue_*`, `registrar_*`, `worker_runtime_*`) and `registerWith`
  takes `Registrar?` whose real type only exists on web.
- **Periodic Background Sync minimum interval**: Chrome enforces ~12 hours.
  Frequencies below that are clamped at registration; DevTools' "Periodic
  Background Sync" panel can still trigger the event manually for testing.
- **Push delivery requires GCM**, which is unavailable in headless Chrome, so
  the automated E2E verified the closed-page path via `periodicsync` (the same
  `wmDispatch` code path push uses). Push itself was left for manual DevTools
  verification.

## Execution flow

```
registerPeriodicTask / registerOneOffTask
  └─ WorkmanagerWeb (page) ── postMessage ──> Service Worker (IndexedDB mirror)

periodicsync / push / fetch (page closed)
  └─ SW: importScripts(bundle) [at startup] → __wmTrigger(...) → Dart handler
       → result recorded in IndexedDB → replayed on next page load ("hello")

periodicsync / push (page open)
  └─ SW relays "workmanager:execute" to clients
       └─ page: Web Worker (compiled bundle) runs handler → result → SW record

registerOneOffTask(initialDelay) (page open)
  └─ page Timer → Web Worker → result
  └─ after deadline, next SW wake runs it if the page was closed
```

## Honest limits (documented in the README)

- No exact scheduling; no arbitrary "run at 15:00".
- Periodic sync: Chromium-only, PWA-installed + engaged, 12h minimum.
- Secure context (HTTPS/localhost) required.
- Dispatcher bundle must be Flutter-free.
- One-off tasks are best-effort when the page is closed (next wake or never).
- Fetch interception is opportunistic, never a reliable wake.
