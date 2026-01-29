import 'package:flutter/material.dart';

/// Slide navigation utilities for consistent app-wide transitions
class NavigationUtils {
  /// Push a new screen with slide-from-right animation
  static Future<T?> slideToScreen<T>(
    BuildContext context,
    Widget screen, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.push<T>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: duration,
        reverseTransitionDuration: duration,
      ),
    );
  }

  /// Push replacement with slide animation
  static Future<T?> slideReplaceScreen<T>(
    BuildContext context,
    Widget screen, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.pushReplacement<T, void>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: duration,
        reverseTransitionDuration: duration,
      ),
    );
  }
}
