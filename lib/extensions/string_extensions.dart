/// Extensions für String
///
/// Erweitert String mit nützlichen Helper-Methoden
extension StringExtensions on String {
  /// Ist der String leer oder nur Whitespace?
  bool get isBlank => trim().isEmpty;

  /// Ist der String nicht leer?
  bool get isNotBlank => !isBlank;

  /// Kapitalisiert den ersten Buchstaben
  String get capitalize {
    if (isEmpty) {
      return this;
    }
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Kapitalisiert jeden Wort-Anfang
  String get capitalizeWords {
    if (isEmpty) {
      return this;
    }
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  /// Entfernt alle Leerzeichen
  String get removeWhitespace => replaceAll(RegExp(r'\s+'), '');

  /// Entfernt führende und nachfolgende Leerzeichen
  String get trimmed => trim();

  /// Konvertiert zu int (null-safe)
  int? toIntOrNull() => int.tryParse(this);

  /// Konvertiert zu double (null-safe)
  double? toDoubleOrNull() => double.tryParse(replaceAll(',', '.'));

  /// Konvertiert zu bool (null-safe)
  bool? toBoolOrNull() {
    final lower = toLowerCase();
    if (lower == 'true' || lower == '1' || lower == 'yes') {
      return true;
    }
    if (lower == 'false' || lower == '0' || lower == 'no') {
      return false;
    }
    return null;
  }

  /// Ist gültige Email? (Basic Check)
  bool get isValidEmail {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(this);
  }

  /// Ist numerisch?
  bool get isNumeric => double.tryParse(this) != null;

  /// Enthält nur Buchstaben?
  bool get isAlphabetic => RegExp(r'^[a-zA-ZäöüßÄÖÜ]+$').hasMatch(this);

  /// Enthält nur Buchstaben und Zahlen?
  bool get isAlphanumeric => RegExp(r'^[a-zA-Z0-9äöüßÄÖÜ]+$').hasMatch(this);

  /// Kürzt String auf maximale Länge
  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) {
      return this;
    }
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }

  /// Deutsche PLZ formatieren (12345 → 12345)
  String get formatPostalCode => removeWhitespace;

  /// Deutsche IBAN formatieren (DE89... → DE89 3704 0044 0532 0130 00)
  String get formatIban {
    final clean = removeWhitespace.toUpperCase();
    if (clean.length != 22) {
      return this;
    }

    return '${clean.substring(0, 4)} '
        '${clean.substring(4, 8)} '
        '${clean.substring(8, 12)} '
        '${clean.substring(12, 16)} '
        '${clean.substring(16, 20)} '
        '${clean.substring(20, 22)}';
  }

  /// Telefonnummer formatieren (nur Ziffern und + behalten)
  String get formatPhone => replaceAll(RegExp(r'[^\d+]'), '');
}
