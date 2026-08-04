// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'web_demo_page.dart';

/// Intro page for the web demo site: what workmanager is, what the demo
/// shows, and links to the upstream project (pub.dev, GitHub, docs).
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  static const String _pubDevUrl = 'https://pub.dev/packages/workmanager';
  static const String _githubUrl =
      'https://github.com/fluttercommunity/flutter_workmanager';
  static const String _docsUrl =
      'https://docs.page/fluttercommunity/flutter_workmanager';
  static const String _issuesUrl =
      'https://github.com/fluttercommunity/flutter_workmanager/issues';

  void _openUrl(String url) {
    final window = globalContext['window'] as JSObject?;
    if (window != null) {
      window.callMethod('open'.toJS, url.toJS);
    }
  }

  void _openDemo(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WebDemoPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildHero(context),
                  const SizedBox(height: 40),
                  Text('What it is', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  const _FeatureCard(
                    icon: Icons.schedule,
                    title: 'One-off & periodic tasks',
                    body: 'Schedule a task to run once — or repeat on an '
                        'interval — with input data, constraints and '
                        'frequency control.',
                  ),
                  const SizedBox(height: 10),
                  const _FeatureCard(
                    icon: Icons.memory,
                    title: 'Runs off the main thread',
                    body: 'Execution happens on the platform\'s own '
                        'schedulers (WorkManager, BGTaskScheduler, Service '
                        'Workers), so your UI never blocks and work keeps '
                        'running when the app is in the background.',
                  ),
                  const SizedBox(height: 10),
                  const _FeatureCard(
                    icon: Icons.devices,
                    title: 'One API, all platforms',
                    body: 'The same callback-dispatcher pattern on Android, '
                        'iOS, Web, Linux and Windows. Web, Linux and '
                        'Windows support is experimental and developed in '
                        'this repository.',
                  ),
                  const SizedBox(height: 40),
                  Text('Try the web demo', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _buildDemoCard(context),
                  const SizedBox(height: 40),
                  Text('Resources', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _buildResourceCard(
                    context,
                    icon: Icons.published_with_changes,
                    title: 'pub.dev',
                    body: 'The published workmanager package.',
                    url: _pubDevUrl,
                  ),
                  const SizedBox(height: 10),
                  _buildResourceCard(
                    context,
                    icon: Icons.code,
                    title: 'GitHub repository',
                    body: 'Source code, releases and the platform packages '
                        '(workmanager_android, workmanager_apple, '
                        'workmanager_web, …).',
                    url: _githubUrl,
                  ),
                  const SizedBox(height: 10),
                  _buildResourceCard(
                    context,
                    icon: Icons.menu_book,
                    title: 'Documentation',
                    body: 'Setup guides and API docs on docs.page.',
                    url: _docsUrl,
                  ),
                  const SizedBox(height: 10),
                  _buildResourceCard(
                    context,
                    icon: Icons.bug_report_outlined,
                    title: 'Issues & feature requests',
                    body: 'Report a bug or ask for a feature on GitHub.',
                    url: _issuesUrl,
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'MIT licensed · maintained by the Flutter Community',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'workmanager',
          style: theme.textTheme.displaySmall?.copyWith(
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Flutter background tasks, done right.',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Schedule one-off and periodic work that runs even when your app '
          'is in the background — or closed. One callback-dispatcher API '
          'across Android, iOS, Web, Linux and Windows.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const <Widget>[
            _PlatformChip(icon: Icons.android, label: 'Android'),
            _PlatformChip(icon: Icons.phone_iphone, label: 'iOS'),
            _PlatformChip(icon: Icons.language, label: 'Web'),
            _PlatformChip(icon: Icons.laptop_mac, label: 'Linux'),
            _PlatformChip(icon: Icons.desktop_windows, label: 'Windows'),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            FilledButton.icon(
              onPressed: () => _openDemo(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Try the live demo'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _openUrl(_pubDevUrl),
              icon: const Icon(Icons.open_in_new),
              label: const Text('View on pub.dev'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDemoCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardFill,
        border: Border.all(color: AppTheme.borderGrey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'A live, self-contained demo of the experimental web support.',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Two-way messaging between the page and a background worker, a '
            'persistent queue of background-task runs (single source of '
            'truth), Service Worker execution and notifications. Everything '
            'is simulated — no sign-up, no server, nothing to install to '
            'explore. Install it as a PWA to unlock the "close the tab and '
            'it still runs" path.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _openDemo(context),
            icon: const Icon(Icons.rocket_launch_outlined),
            label: const Text('Open the demo'),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    required String url,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _openUrl(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderGrey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 22, color: AppTheme.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 18, color: AppTheme.mutedGrey),
          ],
        ),
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: AppTheme.primaryBlue),
      label: Text(label),
      side: const BorderSide(color: AppTheme.borderGrey),
      backgroundColor: Colors.white,
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardFill,
        border: Border.all(color: AppTheme.borderGrey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22, color: AppTheme.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
