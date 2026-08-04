# AGENTS.md — Maintainer & Agent Notes

Operational notes for maintaining this monorepo. Keep this file short — the durable gotchas only.
Code & test conventions (previously in `CLAUDE.md`) are consolidated in the last section.

**All changes to main go through PRs** — no direct pushes to main, including docs and release commits (owner rule, 2026-08-04).

## Tooling
- melos (independent versioning) drives version bumps and publishing. Conventional commit types drive release bumps: `feat` → minor, `fix` → patch. PR titles matter — they become CHANGELOG entries.

## Android / AGP facts
- AGP 9 enables built-in Kotlin **by default**; Flutter apps write `android.builtInKotlin=false` + `android.newDsl=false` in gradle.properties (flutter/flutter#183910).
- The module must apply `kotlin-android` whenever built-in Kotlin is NOT active. Correct guard (same pattern as flutter_timezone):
  `def builtInKotlin = agpMajor >= 9 && project.findProperty('android.builtInKotlin')?.toString() != 'false'`
  Do NOT "simplify" this to `== 'true'`: an absent flag means built-in Kotlin is ON (AGP default), and applying KGP then throws.
- `workmanager_android`'s build.gradle has no Flutter embedding dependency — the module can be built standalone (no Flutter SDK) to repro build issues. In real Flutter builds the FGP injects `io.flutter:flutter_embedding_debug`; `download.flutter.io` has a TLS cert mismatch (artifact only resolvable from the local Gradle cache), so standalone repros use `compileOnly` on the local engine `flutter.jar` + `androidx.core:core-ktx`, wired via an init script.
- When building the plugin through the example app, the FGP relocates the plugin's build dir: unit test results land in `example/build/workmanager_android/`, **not** `workmanager_android/android/build/`. `./gradlew :workmanager_android:testDebugUnitTest` currently runs 50 tests.

## Release process
- Release bumps go through a PR like everything else: branch with the pubspec + CHANGELOG bumps → PR → merge. Then tag the **merged** commit (squash merges change the SHA), push tags, publish, create the GitHub Release.
- Tags: per-package (`workmanager_android-v0.10.5`, `workmanager-v0.10.6`, …) plus root `v0.x.y` (= workmanager version).
- `melos version` is interactive and proposes versions from commit analysis; it bumps dependency-only packages with build metadata (`0.1.1` → `0.1.1+1`). For the root package prefer a clean patch bump: edit pubspecs + CHANGELOGs manually, mirroring melos's exact format (root CHANGELOG date section with anchors, per-package CHANGELOG entries, dependent constraint bumps). This is the one sanctioned exception to the repo's "don't hand-edit CHANGELOGs" rule.
- **main is force-push protected** (server-side hook). Never rewrite main history; bump manually or accept melos's proposal.
- Ship fixes as patch bumps: `^0.10.x` consumers only get patch releases automatically via `flutter pub upgrade`.
- Publish: `dart pub publish --dry-run` per package, then `melos publish --no-dry-run` (interactive — answer `y`). Verify afterwards: `https://pub.dev/api/packages/<name>`.
- **pub.dev publish ≠ GitHub Release.** After publishing + pushing tags, create the GitHub Release from the root tag — users watch the Releases tab, and "Latest" on GitHub tracks it (missed this for v0.10.6, v0.10.5 had one). Mirror the previous release's notes format: `gh release create v0.x.y --title "workmanager v0.x.y — <summary>" --notes "..."`.
- Known dry-run noise (pre-existing, not release blockers): 1 warning/1 hint on workmanager_android, 1 warning/4 hints on workmanager. The `pubspec_overrides.yaml` warning during publish is a melos workspace artifact, harmless.

## GitHub ops
- Fork PRs from first-time contributors have CI stuck on `action_required`; approve via `POST /repos/FlutterCommunity/flutter_workmanager/actions/runs/{id}/approve`.
- Contributor PRs: check `maintainer_can_modify` (`gh api repos/.../pulls/N`). If true, you can push fixup commits to their branch.
- When a contributor's PR is equivalent to yours: adopt theirs (give credit), close yours as superseded.
- CI: `gh pr checks N`; merge with `gh pr merge N --squash --delete-branch`. Validate PR title is a required check — keep titles conventional.

## Code & test conventions
- Pre-commit, from repo root: `dart analyze`, `ktlint -F .`, `swiftlint --fix`, `dart format` (non-generated files), `flutter test`, `cd example/android && ./gradlew :workmanager_android:test`, `cd example && flutter build apk --debug` + `flutter build ios --debug --no-codesign`.
- Codegen via melos (`melos run generate:pigeon`, `melos run generate:dart`); never hand-edit `*.g.dart`/generated mocks — regenerate from source.
- Tests must exercise real logic — no `assert(true)`/compile-only tests; cover edge cases. `BackgroundWorker` is not unit-testable (Flutter engine deps) — integration tests only.
- Changelog entries are user-focused: end-user impact, not internal/build details (e.g. "fixed periodic tasks not respecting frequency changes", not "fixed Kotlin null-safety with androidx.work 2.10.2").
- PR descriptions: short Summary + `Fixes #N`; Breaking Changes section (before/after) only when applicable.
- docs.page: use `<TabItem>` (always with `label` + `value` props), not `<Tab>`.
