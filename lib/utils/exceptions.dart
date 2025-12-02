/// Custom Exceptions für bessere Fehlerbehandlung
///
/// Ermöglicht spezifischere Exception-Handling
library;

/// Basis-Exception für alle App-Exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() {
    if (code != null) {
      return '$runtimeType [$code]: $message';
    }
    return '$runtimeType: $message';
  }
}

// ===== DATENBANK EXCEPTIONS =====

/// Datenbank-bezogene Fehler
class DatabaseException extends AppException {
  const DatabaseException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Datensatz nicht gefunden
class NotFoundException extends DatabaseException {
  final String entity;
  final dynamic id;

  const NotFoundException(
    this.entity,
    this.id, {
    String? code,
    dynamic originalError,
  }) : super(
          '$entity mit ID $id nicht gefunden',
          code: code,
          originalError: originalError,
        );
}

/// Datenbank-Constraint verletzt
class ConstraintViolationException extends DatabaseException {
  final String constraint;

  const ConstraintViolationException(
    this.constraint, {
    String? code,
    dynamic originalError,
  }) : super(
          'Constraint "$constraint" verletzt',
          code: code,
          originalError: originalError,
        );
}

// ===== VALIDIERUNGS EXCEPTIONS =====

/// Validierungsfehler
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException(
    super.message, {
    super.code,
    this.fieldErrors,
    super.originalError,
  });

  /// Hat Feld-Fehler?
  bool get hasFieldErrors => fieldErrors != null && fieldErrors!.isNotEmpty;

  /// Fehler für ein bestimmtes Feld
  String? getFieldError(String field) => fieldErrors?[field];
}

/// Ungültige Eingabe
class InvalidInputException extends ValidationException {
  final String field;

  InvalidInputException(
    this.field,
    String message, {
    String? code,
    dynamic originalError,
  }) : super(
          message,
          code: code,
          fieldErrors: {field: message},
          originalError: originalError,
        );
}

// ===== GESCHÄFTSLOGIK EXCEPTIONS =====

/// Geschäftsregel verletzt
class BusinessRuleException extends AppException {
  const BusinessRuleException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Preis-Berechnung fehlgeschlagen
class PriceCalculationException extends BusinessRuleException {
  const PriceCalculationException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Ruleset-Parsing fehlgeschlagen
class RulesetParseException extends BusinessRuleException {
  final int? line;

  const RulesetParseException(
    super.message, {
    this.line,
    super.code,
    super.originalError,
  });

  @override
  String toString() {
    if (line != null) {
      return 'RulesetParseException [Zeile $line]: $message';
    }
    return super.toString();
  }
}

// ===== IMPORT/EXPORT EXCEPTIONS =====

/// Import/Export Fehler
class ImportExportException extends AppException {
  final String operation; // 'import' oder 'export'
  final String? fileName;

  const ImportExportException(
    this.operation,
    super.message, {
    this.fileName,
    super.code,
    super.originalError,
  });

  @override
  String toString() {
    if (fileName != null) {
      return 'ImportExportException [$operation, $fileName]: $message';
    }
    return 'ImportExportException [$operation]: $message';
  }
}

/// Excel-Import Fehler
class ExcelImportException extends ImportExportException {
  final int? row;
  final String? column;

  const ExcelImportException(
    String message, {
    this.row,
    this.column,
    String? fileName,
    String? code,
    dynamic originalError,
  }) : super(
          'import',
          message,
          fileName: fileName,
          code: code,
          originalError: originalError,
        );

  @override
  String toString() {
    final location = <String>[];
    if (fileName != null) {
      location.add('Datei: $fileName');
    }
    if (row != null) {
      location.add('Zeile: $row');
    }
    if (column != null) {
      location.add('Spalte: $column');
    }

    if (location.isNotEmpty) {
      return 'ExcelImportException [${location.join(', ')}]: $message';
    }
    return super.toString();
  }
}

/// PDF-Export Fehler
class PdfExportException extends ImportExportException {
  const PdfExportException(
    String message, {
    String? fileName,
    String? code,
    dynamic originalError,
  }) : super(
          'export',
          message,
          fileName: fileName,
          code: code,
          originalError: originalError,
        );
}

// ===== NETZWERK EXCEPTIONS =====

/// Netzwerk-Fehler (falls später benötigt)
class NetworkException extends AppException {
  final int? statusCode;

  const NetworkException(
    super.message, {
    this.statusCode,
    super.code,
    super.originalError,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'NetworkException [$statusCode]: $message';
    }
    return super.toString();
  }
}

// ===== PERMISSION EXCEPTIONS =====

/// Berechtigungs-Fehler
class PermissionException extends AppException {
  final String permission;

  const PermissionException(
    this.permission, {
    String? code,
    dynamic originalError,
  }) : super(
          'Berechtigung "$permission" fehlt',
          code: code,
          originalError: originalError,
        );
}

// ===== ALLGEMEINE EXCEPTIONS =====

/// Allgemeine/Unbekannte Fehler
class GeneralException extends AppException {
  const GeneralException(
    super.message, {
    super.code,
    super.originalError,
  });
}

// ===== HELPER FUNCTIONS =====

/// Konvertiert allgemeine Exceptions zu App-Exceptions
AppException toAppException(dynamic error, {String? context}) {
  if (error is AppException) {
    return error;
  }

  // Drift/SQLite Errors
  if (error.toString().contains('UNIQUE constraint failed')) {
    return const ConstraintViolationException('UNIQUE');
  }

  if (error.toString().contains('FOREIGN KEY constraint failed')) {
    return const ConstraintViolationException('FOREIGN KEY');
  }

  // Allgemeiner Fehler
  return GeneralException(
    context != null ? '$context: ${error.toString()}' : error.toString(),
    originalError: error,
  );
}
