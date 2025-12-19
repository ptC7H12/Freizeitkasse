import 'package:http/http.dart' as http;
import '../utils/logger.dart';
import '../utils/exceptions.dart';

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

      AppLogger.info('[GitHubRulesetService] Lade Ruleset von GitHub: $url');

      // HTTP-Request
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw NetworkException('Timeout beim Laden von GitHub');
        },
      );

      if (response.statusCode == 200) {
        AppLogger.info('[GitHubRulesetService] Ruleset erfolgreich geladen: ${response.body.length} Zeichen');
        return response.body;
      } else if (response.statusCode == 404) {
        AppLogger.warning('[GitHubRulesetService] Ruleset nicht gefunden auf GitHub: $url (404)');

        // Versuche Fallback auf generisches Ruleset ohne Jahr
        return await _loadFallbackRuleset(cleanBasePath, normalizedEventType);
      } else {
        AppLogger.error('[GitHubRulesetService] Fehler beim Laden von GitHub: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('[GitHubRulesetService] Exception beim Laden von GitHub', error: e);
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

      AppLogger.info('[GitHubRulesetService] Versuche Fallback-Ruleset: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        AppLogger.info('[GitHubRulesetService] Fallback-Ruleset geladen: ${response.body.length} Zeichen');
        return response.body;
      } else {
        AppLogger.warning('[GitHubRulesetService] Fallback-Ruleset nicht gefunden: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('[GitHubRulesetService] Fehler beim Laden des Fallback-Rulesets', error: e);
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
