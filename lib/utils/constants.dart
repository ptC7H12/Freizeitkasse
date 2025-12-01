import 'package:flutter/material.dart';

/// App-weite Konstanten
///
/// Zentraler Ort für alle wiederverwendbaren Konstanten
class AppConstants {
  // Private constructor um Instanziierung zu verhindern
  AppConstants._();

  // ===== FARBEN =====

  /// Primärfarbe (Material Blue)
  static const Color primaryColor = Color(0xFF2196F3);

  /// Dunklere Variante der Primärfarbe
  static const Color primaryColorDark = Color(0xFF1976D2);

  /// Sekundärfarbe (Grün für positive Aktionen)
  static const Color secondaryColor = Color(0xFF4CAF50);

  /// Tertiärfarbe (Orange für Warnungen/Highlights)
  static const Color tertiaryColor = Color(0xFFFF9800);

  /// Erfolgsfarbe
  static const Color successColor = Color(0xFF4CAF50);

  /// Warnfarbe
  static const Color warningColor = Color(0xFFFF9800);

  /// Fehlerfarbe
  static const Color errorColor = Color(0xFFF44336);

  /// Informationsfarbe
  static const Color infoColor = Color(0xFF2196F3);

  // ===== SPACING =====

  /// Kleiner Abstand (4px)
  static const double spacingXS = 4.0;

  /// Kleiner Abstand (8px)
  static const double spacingS = 8.0;

  /// Mittlerer Abstand (12px)
  static const double spacingM = 12.0;

  /// Standard Abstand (16px)
  static const double spacing = 16.0;

  /// Großer Abstand (24px)
  static const double spacingL = 24.0;

  /// Sehr großer Abstand (32px)
  static const double spacingXL = 32.0;

  /// Riesiger Abstand (48px)
  static const double spacingXXL = 48.0;

  // EdgeInsets Konstanten
  static const EdgeInsets paddingAll4 = EdgeInsets.all(spacingXS);
  static const EdgeInsets paddingAll8 = EdgeInsets.all(spacingS);
  static const EdgeInsets paddingAll12 = EdgeInsets.all(spacingM);
  static const EdgeInsets paddingAll16 = EdgeInsets.all(spacing);
  static const EdgeInsets paddingAll24 = EdgeInsets.all(spacingL);
  static const EdgeInsets paddingAll32 = EdgeInsets.all(spacingXL);

  static const EdgeInsets paddingH16 = EdgeInsets.symmetric(horizontal: spacing);
  static const EdgeInsets paddingV16 = EdgeInsets.symmetric(vertical: spacing);
  static const EdgeInsets paddingH8 = EdgeInsets.symmetric(horizontal: spacingS);
  static const EdgeInsets paddingV8 = EdgeInsets.symmetric(vertical: spacingS);

  // ===== BORDER RADIUS =====

  /// Kleiner Radius (4px)
  static const double radiusS = 4.0;

  /// Standard Radius (8px)
  static const double radius = 8.0;

  /// Mittlerer Radius (12px)
  static const double radiusM = 12.0;

  /// Großer Radius (16px)
  static const double radiusL = 16.0;

  /// Sehr großer Radius (24px)
  static const double radiusXL = 24.0;

  // BorderRadius Konstanten
  static final BorderRadius borderRadius8 = BorderRadius.circular(radius);
  static final BorderRadius borderRadius12 = BorderRadius.circular(radiusM);
  static final BorderRadius borderRadius16 = BorderRadius.circular(radiusL);
  static final BorderRadius borderRadius24 = BorderRadius.circular(radiusXL);

  // ===== ICON SIZES =====

  /// Kleine Icon-Größe (16px)
  static const double iconSizeS = 16.0;

  /// Standard Icon-Größe (24px)
  static const double iconSize = 24.0;

  /// Mittlere Icon-Größe (32px)
  static const double iconSizeM = 32.0;

  /// Große Icon-Größe (40px)
  static const double iconSizeL = 40.0;

  /// Sehr große Icon-Größe (48px)
  static const double iconSizeXL = 48.0;

  // ===== RESPONSIVE =====

  /// Maximale Breite für Formulare auf Desktop
  static const double maxFormWidth = 800.0;

  /// Breakpoint für Tablet (600px)
  static const double breakpointTablet = 600.0;

  /// Breakpoint für Desktop (1200px)
  static const double breakpointDesktop = 1200.0;

  // ===== ELEVATION =====

  /// Keine Elevation
  static const double elevationNone = 0.0;

  /// Geringe Elevation (2px)
  static const double elevationLow = 2.0;

  /// Mittlere Elevation (4px)
  static const double elevationMedium = 4.0;

  /// Hohe Elevation (8px)
  static const double elevationHigh = 8.0;

  /// Sehr hohe Elevation (16px)
  static const double elevationVeryHigh = 16.0;

  // ===== ZAHLUNGSMETHODEN =====

  /// Standard Zahlungsmethoden
  static const List<String> paymentMethods = [
    'Barzahlung',
    'Überweisung',
    'Lastschrift',
    'Kreditkarte',
    'PayPal',
    'Sonstige',
  ];

  // ===== SCHWIMMFÄHIGKEITEN =====

  /// Standard Schwimmfähigkeiten
  static const List<String> swimAbilities = [
    'Nichtschwimmer',
    'Seepferdchen',
    'Bronze',
    'Silber',
    'Gold',
    'Rettungsschwimmer',
  ];

  // ===== VALIDIERUNGS-KONSTANTEN =====

  /// Minimale Passwort-Länge (falls später benötigt)
  static const int minPasswordLength = 8;

  /// Maximale Alter (für realistische Validierung)
  static const int maxRealisticAge = 120;

  /// Deutsche PLZ-Länge
  static const int germanPostalCodeLength = 5;

  /// Deutsche IBAN-Länge
  static const int germanIbanLength = 22;

  // ===== ANIMATION DURATIONS =====

  /// Kurze Animation (150ms)
  static const Duration animationDurationShort = Duration(milliseconds: 150);

  /// Standard Animation (300ms)
  static const Duration animationDuration = Duration(milliseconds: 300);

  /// Lange Animation (500ms)
  static const Duration animationDurationLong = Duration(milliseconds: 500);

  // ===== APP-INFO =====

  /// App-Name
  static const String appName = 'MGB Freizeitplaner';

  /// App-Version (sollte mit pubspec.yaml synchronisiert werden)
  static const String appVersion = '1.0.0';

  /// Build-Nummer
  static const String buildNumber = '1';
}
