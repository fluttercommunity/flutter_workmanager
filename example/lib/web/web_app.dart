// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'landing_page.dart';

/// Root widget for the web demo site: an intro page (what workmanager is,
/// links to the project) plus the runnable demo, sharing one theme.
class WebDemoApp extends StatelessWidget {
  const WebDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workmanager Web Demo',
      theme: AppTheme.light(),
      home: const LandingPage(),
    );
  }
}
