import 'package:flutter/material.dart';

/// Navigation-Helper für konsistente Navigation in der App
///
/// Vereinfacht und standardisiert Navigation-Aufrufe
class RouteHelpers {
  // Private constructor um Instanziierung zu verhindern
  RouteHelpers._();

  /// Navigiert zu einem neuen Screen
  ///
  /// Standard push-Navigation
  static Future<T?> push<T>(BuildContext context, Widget screen) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// Navigiert zu einem neuen Screen und ersetzt den aktuellen
  ///
  /// Nützlich für Login → Dashboard Übergänge
  static Future<T?> pushReplacement<T, TO>(
    BuildContext context,
    Widget screen,
  ) {
    return Navigator.of(context).pushReplacement<T, TO>(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// Navigiert zurück zur vorherigen Route
  ///
  /// Optional mit einem Rückgabewert
  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop(result);
  }

  /// Navigiert zurück bis zur ersten Route (Root)
  ///
  /// Nützlich um zum Dashboard zurückzukehren
  static void popToRoot(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Navigiert zu einem Screen und entfernt alle vorherigen Routes
  ///
  /// Nützlich für Logout → Login
  static Future<T?> pushAndRemoveAll<T>(
    BuildContext context,
    Widget screen,
  ) {
    return Navigator.of(context).pushAndRemoveUntil<T>(
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  /// Navigiert zu einem Screen mit Slide-Animation
  static Future<T?> pushWithSlideTransition<T>(
    BuildContext context,
    Widget screen, {
    SlideDirection direction = SlideDirection.left,
  }) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          Offset begin;
          switch (direction) {
            case SlideDirection.left:
              begin = const Offset(1.0, 0.0);
            case SlideDirection.right:
              begin = const Offset(-1.0, 0.0);
            case SlideDirection.up:
              begin = const Offset(0.0, 1.0);
            case SlideDirection.down:
              begin = const Offset(0.0, -1.0);
          }

          const end = Offset.zero;
          const curve = Curves.easeInOut;

          final tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  /// Navigiert zu einem Screen mit Fade-Animation
  static Future<T?> pushWithFadeTransition<T>(
    BuildContext context,
    Widget screen,
  ) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  /// Prüft ob Navigation möglich ist (canPop)
  static bool canPop(BuildContext context) {
    return Navigator.of(context).canPop();
  }

  /// Sicheres Pop - nur wenn Navigation möglich ist
  static void safePop<T>(BuildContext context, [T? result]) {
    if (canPop(context)) {
      pop(context, result);
    }
  }
}

/// Richtung für Slide-Transition
enum SlideDirection {
  left,
  right,
  up,
  down,
}
