import 'package:flutter/material.dart';
import 'constants.dart';

/// UI-Helper-Funktionen für häufig verwendete UI-Operationen
///
/// Reduziert Code-Duplikation bei SnackBars, Dialogs, etc.
class UIHelpers {
  // Private constructor um Instanziierung zu verhindern
  UIHelpers._();

  // ===== SNACKBARS =====

  /// Zeigt eine Erfolgs-SnackBar
  static void showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Zeigt eine Fehler-SnackBar
  static void showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppConstants.errorColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Zeigt eine Warn-SnackBar
  static void showWarningSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppConstants.warningColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Zeigt eine Info-SnackBar
  static void showInfoSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppConstants.infoColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ===== DIALOGS =====

  /// Zeigt einen Bestätigungs-Dialog
  ///
  /// Gibt `true` zurück wenn bestätigt, `false` wenn abgebrochen
  static Future<bool> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Bestätigen',
    String cancelText = 'Abbrechen',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppConstants.errorColor,
                  )
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Zeigt einen Lösch-Bestätigungs-Dialog
  ///
  /// Spezielle Variante für Lösch-Operationen
  static Future<bool> showDeleteConfirmDialog({
    required BuildContext context,
    required String itemName,
    String? additionalInfo,
  }) async {
    return showConfirmDialog(
      context: context,
      title: '$itemName löschen?',
      message: additionalInfo ??
          'Möchten Sie $itemName wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.',
      confirmText: 'Löschen',
      cancelText: 'Abbrechen',
      isDestructive: true,
    );
  }

  /// Zeigt einen Info-Dialog
  static Future<void> showInfoDialog({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = 'OK',
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  /// Zeigt einen Fehler-Dialog
  static Future<void> showErrorDialog({
    required BuildContext context,
    String title = 'Fehler',
    required String message,
    String buttonText = 'OK',
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppConstants.errorColor),
            const SizedBox(width: AppConstants.spacingM),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  // ===== LOADING =====

  /// Zeigt einen Loading-Dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: AppConstants.spacingL),
              Expanded(
                child: Text(message ?? 'Laden...'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Schließt den Loading-Dialog
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  // ===== RESPONSIVE HELPERS =====

  /// Prüft ob das Device ein Tablet ist
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= AppConstants.breakpointTablet;
  }

  /// Prüft ob das Device ein Desktop ist
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= AppConstants.breakpointDesktop;
  }

  /// Prüft ob das Device ein Smartphone ist
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < AppConstants.breakpointTablet;
  }

  /// Gibt die optimale Anzahl an Spalten für ein Grid zurück
  static int getGridColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= AppConstants.breakpointDesktop) {
      return 4;
    }
    if (width >= AppConstants.breakpointTablet) {
      return 3;
    }
    return 2;
  }
}
