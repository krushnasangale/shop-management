import 'package:flutter/material.dart';

/// Extension on BuildContext to provide easy access to theme-based text styles
/// This ensures consistent text styling across the entire app
extension AppTextStyles on BuildContext {
  // Primary text styles (using bodyLarge - black in light mode, white in dark mode)

  TextStyle? get displayLarge => Theme.of(
    this,
  ).textTheme.bodyLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.bold);

  TextStyle? get displayMedium => Theme.of(
    this,
  ).textTheme.bodyLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.bold);

  TextStyle? get headingLarge => Theme.of(
    this,
  ).textTheme.bodyLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.bold);

  TextStyle? get headingMedium => Theme.of(
    this,
  ).textTheme.bodyLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold);

  TextStyle? get headingSmall => Theme.of(
    this,
  ).textTheme.bodyLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold);

  TextStyle? get titleLarge => Theme.of(
    this,
  ).textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600);

  TextStyle? get titleMedium => Theme.of(
    this,
  ).textTheme.bodyLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600);

  TextStyle? get bodyLargeText =>
      Theme.of(this).textTheme.bodyLarge?.copyWith(fontSize: 16);

  TextStyle? get bodyMediumText =>
      Theme.of(this).textTheme.bodyLarge?.copyWith(fontSize: 14);

  TextStyle? get bodySmallText =>
      Theme.of(this).textTheme.bodyLarge?.copyWith(fontSize: 12);

  // Secondary text styles (using bodyMedium - grey color)

  TextStyle? get subtitleLarge =>
      Theme.of(this).textTheme.bodyMedium?.copyWith(fontSize: 16);

  TextStyle? get subtitleMedium =>
      Theme.of(this).textTheme.bodyMedium?.copyWith(fontSize: 14);

  TextStyle? get subtitleSmall =>
      Theme.of(this).textTheme.bodyMedium?.copyWith(fontSize: 12);

  TextStyle? get captionLarge => Theme.of(
    this,
  ).textTheme.bodyMedium?.copyWith(fontSize: 12, fontStyle: FontStyle.italic);

  TextStyle? get captionMedium => Theme.of(
    this,
  ).textTheme.bodyMedium?.copyWith(fontSize: 10, fontStyle: FontStyle.italic);

  // Direct access to theme colors

  Color? get primaryTextColor => Theme.of(this).textTheme.bodyLarge?.color;

  Color? get secondaryTextColor => Theme.of(this).textTheme.bodyMedium?.color;

  Color? get primaryColor => Theme.of(this).colorScheme.primary;

  Color? get cardColor => Theme.of(this).cardTheme.color;

  Color? get backgroundColor => Theme.of(this).scaffoldBackgroundColor;
}
