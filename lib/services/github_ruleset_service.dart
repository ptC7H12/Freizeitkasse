import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

/// GitHub Ruleset Import Service
///
/// Lädt Regelwerk-Templates von GitHub basierend auf Freizeittyp und Jahr
/// Pattern: {Freizeittyp}_{Jahr}.yaml
class GitHubRulesetService {
  /// Lädt Ruleset von GitHub
  ///
  /// Args:
  ///   - githubBasePath: Basis-URL zu GitHub (z.B. https://raw.githubusercontent.com/user/repo/main/rulesets)
  ///   - eventType: Freizeittyp (Kinderfreizeit, Teeniefreizeit, etc.)
  ///   - year: Jahr der Freizeit (z.B. 2025)
  ///
  /// Returns:
  ///   YAML-String oder null bei Fehler
  static Future<String?> loadRulesetFromGitHub({
    required String githubBasePath,
    required String eventType,
    required int year,
  }) async {
    try {
      // Basis-Pfad bereinigen (trailing slash entfernen)
      String cleanBasePath = githubBasePath.trim();
      if (cleanBasePath.endsWith('/')) {
        cleanBasePath = cleanBasePath.substring(0, cleanBasePath.length - 1);
      }

      // Eventtyp normalisieren (Leerzeichen entfernen für Dateiname)
      final normalizedEventType = _normalizeEventType(eventType);

      // Pattern: {Freizeittyp}_{Jahr}.yaml
      final fileName = '${normalizedEventType}_$year.yaml';
      final url = '$cleanBasePath/$fileName';

      developer.log(
        'Lade Ruleset von GitHub: $url',
        name: 'GitHubRulesetService',
      );

      // HTTP-Request
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout beim Laden von GitHub');
        },
      );

      if (response.statusCode == 200) {
        developer.log(
          'Ruleset erfolgreich geladen: ${response.body.length} Zeichen',
          name: 'GitHubRulesetService',
        );
        return response.body;
      } else if (response.statusCode == 404) {
        developer.log(
          'Ruleset nicht gefunden auf GitHub: $url (404)',
          name: 'GitHubRulesetService',
          level: 900, // Warning
        );

        // Versuche Fallback auf generisches Ruleset ohne Jahr
        return await _loadFallbackRuleset(cleanBasePath, normalizedEventType);
      } else {
        developer.log(
          'Fehler beim Laden von GitHub: ${response.statusCode}',
          name: 'GitHubRulesetService',
          level: 1000, // Error
        );
        return null;
      }
    } catch (e) {
      developer.log(
        'Exception beim Laden von GitHub: $e',
        name: 'GitHubRulesetService',
        level: 1000, // Error
      );
      return null;
    }
  }

  /// Versucht ein generisches Ruleset ohne Jahr zu laden
  ///
  /// Pattern: {Freizeittyp}.yaml
  static Future<String?> _loadFallbackRuleset(
    String basePath,
    String normalizedEventType,
  ) async {
    try {
      final fileName = '$normalizedEventType.yaml';
      final url = '$basePath/$fileName';

      developer.log(
        'Versuche Fallback-Ruleset: $url',
        name: 'GitHubRulesetService',
      );

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        developer.log(
          'Fallback-Ruleset geladen: ${response.body.length} Zeichen',
          name: 'GitHubRulesetService',
        );
        return response.body;
      } else {
        developer.log(
          'Fallback-Ruleset nicht gefunden: ${response.statusCode}',
          name: 'GitHubRulesetService',
          level: 900, // Warning
        );
        return null;
      }
    } catch (e) {
      developer.log(
        'Fehler beim Laden des Fallback-Rulesets: $e',
        name: 'GitHubRulesetService',
        level: 1000, // Error
      );
      return null;
    }
  }

  /// Normalisiert Eventtyp für Dateinamen
  ///
  /// Beispiele:
  /// - "Kinderfreizeit" -> "Kinderfreizeit"
  /// - "Teenie Freizeit" -> "Teeniefreizeit"
  /// - "Sonstige" -> "Sonstige"
  static String _normalizeEventType(String eventType) {
    // Leerzeichen entfernen
    return eventType.replaceAll(' ', '');
  }

  /// Generiert erwartete Dateinamen für UI-Anzeige
  ///
  /// Returns: Map mit primary und fallback Dateinamen
  static Map<String, String> getExpectedFileNames({
    required String eventType,
    required int year,
  }) {
    final normalized = _normalizeEventType(eventType);
    return {
      'primary': '${normalized}_$year.yaml',
      'fallback': '$normalized.yaml',
    };
  }
}
