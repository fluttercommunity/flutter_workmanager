## 0.1.1+1

 - Update a dependency to the latest release.

## 0.1.1

 - **FEAT**(linux): workmanager_linux — systemd-based background execution (fixes #324) (#716).

## 0.1.0

- Experimental Linux implementation of `workmanager` using systemd user
  units:
  - one-off tasks via transient `systemd-run --user` units,
  - periodic tasks via `.timer`/`.service` unit pairs
    (`OnUnitActiveSec`, `Persistent=true` for catch-up),
  - headless `--background-task` execution mode for the callback dispatcher.
- No native code, no Pigeon: pure Dart talking to `systemctl`/`systemd-run`
  through an injectable process runner.
