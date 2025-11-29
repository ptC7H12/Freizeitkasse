import 'package:flutter/material.dart';
import '../utils/ui_helpers.dart';
import '../utils/route_helpers.dart';

/// Extensions für BuildContext
///
/// Erweitert BuildContext mit nützlichen Helper-Methoden
extension ContextExtensions on BuildContext {
  // ===== THEME =====

  /// Zugriff auf das Theme
  ThemeData get theme => Theme.of(this);

  /// Zugriff auf die ColorScheme
  ColorScheme get colorScheme => theme.colorScheme;

  /// Zugriff auf die TextTheme
  TextTheme get textTheme => theme.textTheme;

  /// Primärfarbe
  Color get primaryColor => colorScheme.primary;

  /// Sekundärfarbe
  Color get secondaryColor => colorScheme.secondary;

  /// Hintergrundfarbe
  Color get backgroundColor => colorScheme.surface;

  /// Fehlerfarbe
  Color get errorColor => colorScheme.error;

  // ===== MEDIA QUERY =====

  /// Zugriff auf MediaQuery
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Screen-Größe
  Size get screenSize => mediaQuery.size;

  /// Screen-Breite
  double get screenWidth => screenSize.width;

  /// Screen-Höhe
  double get screenHeight => screenSize.height;

  /// Padding (z.B. für notch)
  EdgeInsets get padding => mediaQuery.padding;

  /// View Insets (z.B. Tastatur)
  EdgeInsets get viewInsets => mediaQuery.viewInsets;

  /// Ist Tastatur sichtbar?
  bool get isKeyboardVisible => viewInsets.bottom > 0;

  // ===== RESPONSIVE =====

  /// Ist Mobile?
  bool get isMobile => UIHelpers.isMobile(this);

  /// Ist Tablet?
  bool get isTablet => UIHelpers.isTablet(this);

  /// Ist Desktop?
  bool get isDesktop => UIHelpers.isDesktop(this);

  // ===== NAVIGATION =====

  /// Navigiere zu Screen
  Future<T?> pushScreen<T>(Widget screen) => RouteHelpers.push<T>(this, screen);

  /// Navigiere und ersetze
  Future<T?> pushReplacementScreen<T, TO>(Widget screen) =>
      RouteHelpers.pushReplacement<T, TO>(this, screen);

  /// Navigiere zurück
  void popScreen<T>([T? result]) => RouteHelpers.pop<T>(this, result);

  /// Navigiere zum Root
  void popToRoot() => RouteHelpers.popToRoot(this);

  /// Kann zurück navigieren?
  bool get canPop => RouteHelpers.canPop(this);

  // ===== SNACKBARS =====

  /// Zeige Erfolgs-SnackBar
  void showSuccess(String message) =>
      UIHelpers.showSuccessSnackbar(this, message);

  /// Zeige Fehler-SnackBar
  void showError(String message) => UIHelpers.showErrorSnackbar(this, message);

  /// Zeige Warn-SnackBar
  void showWarning(String message) =>
      UIHelpers.showWarningSnackbar(this, message);

  /// Zeige Info-SnackBar
  void showInfo(String message) => UIHelpers.showInfoSnackbar(this, message);

  // ===== DIALOGS =====

  /// Zeige Bestätigungs-Dialog
  Future<bool> showConfirm({
    required String title,
    required String message,
    String confirmText = 'Bestätigen',
    String cancelText = 'Abbrechen',
    bool isDestructive = false,
  }) =>
      UIHelpers.showConfirmDialog(
        context: this,
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
      );

  /// Zeige Lösch-Bestätigungs-Dialog
  Future<bool> showDeleteConfirm(String itemName, {String? additionalInfo}) =>
      UIHelpers.showDeleteConfirmDialog(
        context: this,
        itemName: itemName,
        additionalInfo: additionalInfo,
      );

  /// Zeige Info-Dialog
  Future<void> showInfoDialog({
    required String title,
    required String message,
    String buttonText = 'OK',
  }) =>
      UIHelpers.showInfoDialog(
        context: this,
        title: title,
        message: message,
        buttonText: buttonText,
      );

  /// Zeige Fehler-Dialog
  Future<void> showErrorDialog({
    String title = 'Fehler',
    required String message,
    String buttonText = 'OK',
  }) =>
      UIHelpers.showErrorDialog(
        context: this,
        title: title,
        message: message,
        buttonText: buttonText,
      );

  // ===== FOCUS =====

  /// Unfocus (Tastatur schließen)
  void unfocus() => FocusScope.of(this).unfocus();

  /// Request Focus
  void requestFocus(FocusNode node) => FocusScope.of(this).requestFocus(node);
}
