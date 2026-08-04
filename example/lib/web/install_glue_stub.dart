// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// VM-safe stand-in for [InstallGlue] (keeps the example analyzable on native
/// platforms).
class InstallGlue {
  InstallGlue._();

  /// Listens for `beforeinstallprompt`/`appinstalled` (no-op on non-web
  /// platforms).
  static void listen() {}

  /// Whether the browser fired `beforeinstallprompt`.
  static bool get canPrompt => false;

  /// Whether the app is installed as a PWA (always false on non-web).
  static bool installed = false;

  /// Called whenever [installed] becomes true.
  static void Function()? onInstalled;

  /// Shows the browser's PWA install prompt (no-op on non-web platforms).
  static Future<bool> promptInstall() async => false;
}
