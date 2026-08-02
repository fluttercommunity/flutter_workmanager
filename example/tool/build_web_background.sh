#!/usr/bin/env bash
#
# Builds the compiled, Flutter-free dispatcher bundle used by the in-page Web
# Worker and by the Service Worker, and refreshes the managed copy of the
# Service Worker script.
#
# Usage: tool/build_web_background.sh (from the example/ directory)
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Compiling web/background.dart -> web/background.dart.js ..."
dart compile js --no-source-maps -O2 web/background.dart -o web/background.dart.js
rm -f web/background.dart.js.deps

echo "Copying workmanager_web Service Worker ..."
cp ../workmanager_web/web/workmanager_service_worker.js web/workmanager_service_worker.js

echo "Done."
