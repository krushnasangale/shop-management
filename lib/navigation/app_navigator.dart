import 'package:flutter/material.dart';

class AppNavigator {
  /// Pushes a new page with a fade transition (default)
  static Future<T?> push<T>(
    BuildContext context,
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => page,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: duration,
      ),
    );
  }

  /// Optionally add more transitions
  static Future<T?> pushSlide<T>(
    BuildContext context,
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOut,
  }) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => page,
        transitionsBuilder: (_, animation, _, child) {
          final offsetAnimation = Tween(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: curve));

          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: duration,
      ),
    );
  }

  /// For replacing current screen (no back)
  static Future<T?> pushReplacement<T>(
    BuildContext context,
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => page,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: duration,
      ),
    );
  }
}
