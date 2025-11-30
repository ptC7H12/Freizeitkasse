import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Zentrales Logging für die App
///
/// Verwendung:
/// ```dart
/// AppLogger.debug('Debug-Nachricht');
/// AppLogger.info('Info-Nachricht');
/// AppLogger.warning('Warnung');
/// AppLogger.error('Fehler aufgetreten', error: exception);
/// ```
class AppLogger {
  static final Logger _logger = Logger(
    filter: ProductionFilter(),
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kDebugMode ? Level.debug : Level.warning,
  );

  /// Debug-Level Logging (nur im Debug-Modus)
  static void debug(String message, [dynamic data]) {
    if (kDebugMode) {
      _logger.d(message, error: data);
    }
  }

  /// Info-Level Logging
  static void info(String message, [dynamic data]) {
    _logger.i(message, error: data);
  }

  /// Warning-Level Logging
  static void warning(String message, [dynamic data]) {
    _logger.w(message, error: data);
  }

  /// Error-Level Logging
  static void error(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Fatal-Level Logging (schwerwiegende Fehler)
  static void fatal(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// Trace-Level Logging (sehr detailliert, nur im Debug-Modus)
  static void trace(String message, [dynamic data]) {
    if (kDebugMode) {
      _logger.t(message, error: data);
    }
  }
}
