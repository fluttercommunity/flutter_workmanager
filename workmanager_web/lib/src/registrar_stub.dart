// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// VM-safe stand-in for the web plugin registrar type.
///
/// The real `Registrar` comes from `package:flutter_web_plugins`, which
/// imports `dart:ui_web` and therefore cannot be imported on the VM. This
/// stub keeps the package analyzable and testable on native platforms; the
/// generated web plugin registrant (which calls `registerWith`) only exists in
/// web builds, where the real type is used instead.
class Registrar {
  Registrar._();
}
