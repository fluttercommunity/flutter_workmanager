// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Shared high-contrast palette and theme for the web demo app (landing page
/// and demo), so both stay visually consistent.
abstract final class AppTheme {
  // High-contrast status colors, readable on white.
  static const Color okGreen = Color(0xFF1E8E3E);
  static const Color alertRed = Color(0xFFC5221F);
  static const Color warnOrange = Color(0xFFB06000);
  static const Color infoBlue = Color(0xFF174EA6);
  static const Color mutedGrey = Color(0xFF5B6670);

  // Surfaces.
  static const Color primaryBlue = Color(0xFF0B57D0);
  static const Color primaryContainer = Color(0xFFD3E3FD);
  static const Color onPrimaryContainer = Color(0xFF001B3F);
  static const Color cardFill = Color(0xFFF1F4F8);
  static const Color borderGrey = Color(0xFFB0B8BF);
  static const Color surfaceHighest = Color(0xFFE1E5E8);
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF1F1F1F);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
      ).copyWith(
        primary: primaryBlue,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        surface: Colors.white,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        outline: mutedGrey,
        outlineVariant: borderGrey,
        surfaceContainerHighest: surfaceHighest,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 15, color: textPrimary),
        bodySmall: TextStyle(fontSize: 14, color: textSecondary),
        labelLarge: TextStyle(fontSize: 14, color: textPrimary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: primaryContainer,
        indicatorColor: Colors.white,
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(color: borderGrey),
    );
  }
}
