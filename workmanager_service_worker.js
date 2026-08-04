// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.
//
// workmanager_web — Service Worker.
//
// This file is JS-only: a full Dart isolate cannot run inside a Service
// Worker. Instead the Dart API registers this worker with the URL of a
// compiled, Flutter-free dart2js dispatcher bundle as a query parameter
// (`?dispatcherUrl=...`). The bundle is imported synchronously at startup
// (importScripts is only allowed during top-level Service Worker execution)
// and exposes `self.__wmTrigger(taskName, inputData)` returning a Promise.
//
// Wake events (Periodic Background Sync, Web Push, fetch interception):
//   1. If a page is open, the task is relayed to the page, which executes it
//      through the Dart runtime (Web Worker or in-page fallback) and reports
//      the outcome back here.
//   2. If no page is open, the compiled Dart dispatcher is invoked directly
//      in this Service Worker global and the result is recorded in IndexedDB.
//      Recorded events are replayed to the page on the next load ("hello").
//
// Copy this file into your app's `web/` folder and serve it at
// `/workmanager_service_worker.js` (the default used by the Dart API).
'use strict';

/* ============================== Configuration ============================== */

const WM_QUERY = new URL(self.location.href).searchParams;
const WM_DISPATCHER_URL = WM_QUERY.get('dispatcherUrl') || '/background.dart.js';

const WM_DB_NAME = 'workmanager_web';
const WM_DB_VERSION = 1;
const WM_MAX_EVENTS = 200;

// Guards against duplicate dispatch bursts from overlapping wake events.
const WM_MIN_DISPATCH_INTERVAL_MS = 60 * 1000;

/* ================================ In-memory state ========================= */

let wmDb = null;
let wmDispatcherReady = false;
let wmTasks = new Map(); // uniqueName -> task
let wmEvents = [];
let wmLastDispatchAt = new Map(); // uniqueName -> timestamp

// The compiled Dart dispatcher bundle is a plain dart2js program whose main()
// exposes self.__wmTrigger(taskName, inputData). importScripts is synchronous
// and only legal during top-level execution of the Service Worker script, so
// this must happen here (the URL comes from the registration query string).
try {
  importScripts(WM_DISPATCHER_URL);
  wmDispatcherReady = typeof self.__wmTrigger === 'function';
} catch (e) {
  wmDispatcherReady = false;
  console.warn(
    '[workmanager_web] Could not import the Dart dispatcher bundle from "' +
      WM_DISPATCHER_URL +
      '": ' +
      e +
      '. The Service Worker will run in relay-only mode.',
  );
}
if (!wmDispatcherReady) {
  // dart2js may defer the bundle's main() to a microtask after importScripts
  // returns, so re-check shortly after startup before giving up.
  setTimeout(() => {
    wmDispatcherReady = typeof self.__wmTrigger === 'function';
    if (!wmDispatcherReady) {
      console.warn(
        '[workmanager_web] The Dart dispatcher bundle at "' +
          WM_DISPATCHER_URL +
          '" loaded but did not expose self.__wmTrigger. ' +
          'Ensure the bundle entrypoint calls WorkmanagerWebWorker.run(...).',
      );
    }
  }, 250);
}

/* =============================== IndexedDB helpers ========================= */

function wmOpenDb() {
  if (wmDb) {
    return Promise.resolve(wmDb);
  }
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(WM_DB_NAME, WM_DB_VERSION);
    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      if (!db.objectStoreNames.contains('tasks')) {
        db.createObjectStore('tasks', { keyPath: 'uniqueName' });
      }
      if (!db.objectStoreNames.contains('events')) {
        db.createObjectStore('events', { keyPath: 'id' });
      }
    };
    request.onsuccess = () => {
      wmDb = request.result;
      resolve(wmDb);
    };
    request.onerror = () => reject(request.error);
  });
}

async function wmLoadState() {
  try {
    const db = await wmOpenDb();
    const tasks = await new Promise((resolve, reject) => {
      const request = db.transaction('tasks', 'readonly')
        .objectStore('tasks').getAll();
      request.onsuccess = () => resolve(request.result || []);
      request.onerror = () => reject(request.error);
    });
    const events = await new Promise((resolve, reject) => {
      const request = db.transaction('events', 'readonly')
        .objectStore('events').getAll();
      request.onsuccess = () => resolve(request.result || []);
      request.onerror = () => reject(request.error);
    });
    wmTasks = new Map(tasks.map((task) => [task.uniqueName, task]));
    wmEvents = events.slice(-WM_MAX_EVENTS).reverse();
  } catch (e) {
    console.warn('[workmanager_web] Could not load persisted state', e);
  }
}

function wmPersistTasks() {
  return wmOpenDb().then((db) => {
    return new Promise((resolve) => {
      const tx = db.transaction('tasks', 'readwrite');
      const store = tx.objectStore('tasks');
      store.clear();
      for (const task of wmTasks.values()) {
        store.put(task);
      }
      tx.oncomplete = () => resolve();
      tx.onerror = () => resolve();
      tx.onabort = () => resolve();
    });
  }).catch((e) => {
    console.warn('[workmanager_web] Could not persist tasks', e);
  });
}

function wmRecordEvent(event) {
  event.id = 'evt-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8);
  event.ts = Date.now();
  wmEvents.unshift(event);
  if (wmEvents.length > WM_MAX_EVENTS) {
    wmEvents.length = WM_MAX_EVENTS;
  }
  wmOpenDb().then((db) => {
    return new Promise((resolve) => {
      const tx = db.transaction('events', 'readwrite');
      tx.objectStore('events').put(event);
      tx.oncomplete = () => resolve();
      tx.onerror = () => resolve();
      tx.onabort = () => resolve();
    });
  }).catch(() => {});
  // Keep any open page's log up to date.
  self.clients.matchAll({ type: 'window', includeUncontrolled: true })
    .then((clients) => {
      for (const client of clients) {
        client.postMessage({ type: 'workmanager:event', event });
      }
    })
    .catch(() => {});
  return event;
}

/* ============================== Task dispatch ============================== */

async function wmDispatch(task, source) {
  if (!task) {
    return;
  }
  const now = Date.now();
  const last = wmLastDispatchAt.get(task.uniqueName) || 0;
  if (now - last < WM_MIN_DISPATCH_INTERVAL_MS) {
    return;
  }
  wmLastDispatchAt.set(task.uniqueName, now);

  const clients = await self.clients.matchAll({
    type: 'window',
    includeUncontrolled: true,
  });
  if (clients.length > 0) {
    // Page open: let the Dart runtime run the callback (Web Worker).
    for (const client of clients) {
      client.postMessage({
        type: 'workmanager:execute',
        uniqueName: task.uniqueName,
        taskName: task.taskName,
        inputData: task.inputData || null,
        source,
      });
    }
    wmRecordEvent({
      source,
      uniqueName: task.uniqueName,
      taskName: task.taskName,
      state: 'relayed',
      message: 'Relayed to an open page.',
    });
    wmTouchTask(task.uniqueName);
    return;
  }

  if (!wmDispatcherReady) {
    wmRecordEvent({
      source,
      uniqueName: task.uniqueName,
      taskName: task.taskName,
      state: 'missed',
      message:
        'No page is open and the Dart dispatcher bundle is not available in ' +
        'this Service Worker, so the callback could not run. Compile the ' +
        'Flutter-free dispatcher with dart2js and serve it at ' +
        WM_DISPATCHER_URL +
        '.',
    });
    wmTouchTask(task.uniqueName);
    return;
  }

  try {
    const result = await wmCallDispatcher(task.taskName, task.inputData || null);
    wmRecordEvent({
      source,
      uniqueName: task.uniqueName,
      taskName: task.taskName,
      state: 'executed',
      inServiceWorker: true,
      result: result === undefined ? null : result,
    });
  } catch (e) {
    wmRecordEvent({
      source,
      uniqueName: task.uniqueName,
      taskName: task.taskName,
      state: 'error',
      inServiceWorker: true,
      message: String((e && e.stack) || e),
    });
  }
  wmTouchTask(task.uniqueName);
}

// The compiled Dart dispatcher bundle exposes a callback-style entry point
// (dart2js cannot export async functions directly); wrap it in a Promise.
function wmCallDispatcher(taskName, inputData) {
  if (typeof self.__wmTrigger !== 'function') {
    return Promise.reject(new Error('Dart dispatcher is not loaded.'));
  }
  return new Promise((resolve, reject) => {
    self.__wmTrigger(taskName, inputData, (result, error) => {
      if (error) {
        reject(new Error(String(error)));
      } else {
        resolve(result);
      }
    });
  });
}

function wmTouchTask(uniqueName) {
  const task = wmTasks.get(uniqueName);
  if (task) {
    task.lastRunAt = Date.now();
    wmPersistTasks();
  }
}

function wmDuePeriodicTasks(now) {
  const due = [];
  for (const task of wmTasks.values()) {
    if (task.type !== 'periodic') {
      continue;
    }
    const frequency = task.frequencyMs || 12 * 60 * 60 * 1000;
    const lastRun = task.lastRunAt || 0;
    if (now - lastRun >= frequency) {
      due.push(task);
    }
  }
  return due;
}

function wmOverdueOneOffTasks(now) {
  const due = [];
  for (const task of wmTasks.values()) {
    if (task.type !== 'oneOff') {
      continue;
    }
    if (task.runAt && now >= task.runAt) {
      due.push(task);
      wmTasks.delete(task.uniqueName);
    }
  }
  if (due.length > 0) {
    wmPersistTasks();
  }
  return due;
}

function wmUnregisterPeriodicSync(tags) {
  if (!self.registration || !self.registration.periodicSync) {
    return;
  }
  for (const tag of tags) {
    self.registration.periodicSync.unregister(tag).catch((e) => {
      console.warn('[workmanager_web] Could not unregister periodic sync ' + tag, e);
    });
  }
}

/* ============================== Lifecycle events ========================== */

self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    Promise.all([self.clients.claim(), wmLoadState()]).catch((e) => {
      console.warn('[workmanager_web] activate failed', e);
    }),
  );
});

// Load persisted tasks/events as early as possible (also covers cold starts
// where activate handlers are not re-run in every browser).
wmLoadState();

/* ============================ Periodic Background Sync ===================== */

self.addEventListener('periodicsync', (event) => {
  const task = wmTasks.get(event.tag);
  event.waitUntil(
    Promise.all([
      task ? wmDispatch(task, 'periodicsync') : Promise.resolve(),
      wmRunOverdueOneOffTasks('periodicsync'),
    ]),
  );
});

/* ================================== Web Push =============================== */

self.addEventListener('push', (event) => {
  event.waitUntil(
    (async () => {
      let payload = null;
      try {
        payload = event.data ? event.data.json() : null;
      } catch (e) {
        payload = null;
      }

      let task = null;
      if (payload && typeof payload.uniqueName === 'string' &&
          wmTasks.has(payload.uniqueName)) {
        task = wmTasks.get(payload.uniqueName);
      } else if (payload && typeof payload.taskName === 'string') {
        task = {
          uniqueName: payload.uniqueName || 'push-' + payload.taskName,
          taskName: payload.taskName,
          inputData: payload.inputData || null,
          type: 'oneOff',
        };
      } else if (wmTasks.size > 0) {
        task = wmTasks.values().next().value;
      }

      const pushes = task ? wmDispatch(task, 'push') : Promise.resolve();
      await Promise.all([pushes, wmRunOverdueOneOffTasks('push')]);

      if (payload && payload.title) {
        await self.registration.showNotification(payload.title, {
          body: payload.body ||
            'Background task "' + (task ? task.taskName : '?') + '" ran.',
          tag: payload.uniqueName || 'workmanager-web',
        });
}

// Runs any one-off tasks whose runAt deadline has passed. Called on every
// Service Worker wake (periodic sync, push, fetch) so one-off tasks that were
// scheduled while the page was open still run (best-effort) after the page is
// closed.
function wmRunOverdueOneOffTasks(source) {
  const now = Date.now();
  const due = wmOverdueOneOffTasks(now);
  if (due.length === 0) {
    return Promise.resolve();
  }
  return Promise.all(due.map((task) => wmDispatch(task, source)));
}
    })(),
  );
});

/* ============================ Fetch interception =========================== */

// Opportunistic wake: a same-origin request can fire due periodic tasks and
// overdue one-off tasks while no page is open. This is NOT a reliable wake
// mechanism (browsers throttle Service Worker fetch events), it never modifies
// responses, and it never intercepts scripts or the dispatcher bundle itself.
self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (!request || request.method !== 'GET') {
    return;
  }
  let url;
  try {
    url = new URL(request.url);
  } catch (e) {
    return;
  }
  if (url.origin !== self.location.origin) {
    return;
  }
  const destination = request.destination;
  if (destination === 'script' || destination === 'worker' ||
      destination === 'serviceworker' || destination === 'style' ||
      destination === 'font') {
    return;
  }
  if (url.pathname.includes('background.dart.js') ||
      url.pathname.includes('workmanager_service_worker.js')) {
    return;
  }
  const now = Date.now();
  const due = wmDuePeriodicTasks(now).concat(wmOverdueOneOffTasks(now));
  if (due.length > 0) {
    event.waitUntil(Promise.all(due.map((task) => wmDispatch(task, 'fetch'))));
  }
});

/* ================================ Messages ================================ */

self.addEventListener('message', (event) => {
  const data = event.data || {};
  const source = event.source;
  switch (data.type) {
    case 'workmanager:hello': {
      if (source && source.postMessage) {
        source.postMessage({
          type: 'workmanager:hello',
          events: wmEvents.slice(0, 50),
          tasks: Array.from(wmTasks.values()),
          dispatcherReady: wmDispatcherReady,
          triggerType: typeof self.__wmTrigger,
        });
      }
      break;
    }
    case 'workmanager:setTasks': {
      const incoming = data.tasks || [];
      const oldPeriodic = Array.from(wmTasks.values())
        .filter((task) => task.type === 'periodic')
        .map((task) => task.uniqueName);
      const newPeriodic = incoming
        .filter((task) => task.type === 'periodic')
        .map((task) => task.uniqueName);
      wmTasks = new Map();
      for (const task of incoming) {
        wmTasks.set(task.uniqueName, task);
      }
      wmPersistTasks();
      const removed = oldPeriodic.filter(
        (uniqueName) => newPeriodic.indexOf(uniqueName) === -1,
      );
      if (removed.length > 0) {
        wmUnregisterPeriodicSync(removed);
      }
      break;
    }
    case 'workmanager:taskExecuted': {
      wmRecordEvent({
        source: data.source || 'page',
        uniqueName: data.uniqueName,
        taskName: data.taskName,
        state: data.error ? 'error' : 'executed',
        result: data.error ? undefined : data.result,
        message: data.error || undefined,
      });
      if (data.removeTask && data.uniqueName) {
        wmTasks.delete(data.uniqueName);
        wmPersistTasks();
      }
      break;
    }
    case 'workmanager:trigger': {
      const task = {
        uniqueName: data.uniqueName || 'trigger-' + data.taskName,
        taskName: data.taskName,
        inputData: data.inputData || null,
        type: 'oneOff',
      };
      event.waitUntil(wmDispatch(task, data.source || 'trigger'));
      break;
    }
    case 'workmanager:cancelAll': {
      const tags = Array.from(wmTasks.values())
        .filter((task) => task.type === 'periodic')
        .map((task) => task.uniqueName);
      wmTasks = new Map();
      wmPersistTasks();
      wmUnregisterPeriodicSync(tags);
      break;
    }
  }
});
