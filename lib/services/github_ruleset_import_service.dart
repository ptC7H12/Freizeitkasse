import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../utils/logger.dart';

/// Service to import rulesets from GitHub
class GithubRulesetImportService {
  /// Parse GitHub URL to extract owner, repo, and path
  ///
  /// Example: https://github.com/ptC7H12/MGBFreizeitplaner/tree/main/rulesets/valid
  /// Returns: {owner: ptC7H12, repo: MGBFreizeitplaner, path: rulesets/valid}
  static Map<String, String>? parseGithubUrl(String url) {
    try {
      final uri = Uri.parse(url);

      if (uri.host != 'github.com') {
        AppLogger.warning('Invalid GitHub URL: not from github.com');
        return null;
      }

      final segments = uri.pathSegments;

      if (segments.length < 4) {
        AppLogger.warning('Invalid GitHub URL: not enough path segments');
        return null;
      }

      final owner = segments[0];
      final repo = segments[1];

      // Remove 'tree' or 'blob' and branch name from path
      final pathStartIndex = segments.indexOf('tree') != -1
          ? segments.indexOf('tree') + 2  // Skip 'tree' and branch name
          : segments.indexOf('blob') != -1
              ? segments.indexOf('blob') + 2  // Skip 'blob' and branch name
              : 2;  // Just owner/repo/path

      final path = segments.sublist(pathStartIndex).join('/');

      return {
        'owner': owner,
        'repo': repo,
        'path': path,
      };
    } catch (e, stack) {
      AppLogger.error('Failed to parse GitHub URL', error: e, stackTrace: stack);
      return null;
    }
  }

  /// List YAML files in a GitHub directory
  ///
  /// Returns a list of file information with name and download_url
  static Future<List<Map<String, dynamic>>> listYamlFiles(String githubUrl) async {
    try {
      final parsed = parseGithubUrl(githubUrl);

      if (parsed == null) {
        throw Exception('Invalid GitHub URL format');
      }

      final owner = parsed['owner'];
      final repo = parsed['repo'];
      final path = parsed['path'];

      // GitHub Contents API
      final apiUrl = 'https://api.github.com/repos/$owner/$repo/contents/$path';

      AppLogger.info('Fetching GitHub directory contents', apiUrl);

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('GitHub API error: ${response.statusCode} - ${response.body}');
      }

      final List<dynamic> contents = json.decode(response.body);

      // Filter for YAML files
      final yamlFiles = contents.where((file) {
        final name = file['name'] as String;
        return (name.endsWith('.yaml') || name.endsWith('.yml')) &&
               file['type'] == 'file';
      }).map((file) => {
        'name': file['name'] as String,
        'download_url': file['download_url'] as String,
        'path': file['path'] as String,
      }).toList();

      AppLogger.info('Found ${yamlFiles.length} YAML files');
      return yamlFiles;
    } catch (e, stack) {
      AppLogger.error('Failed to list YAML files from GitHub', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Download a file from GitHub by its download_url
  static Future<String> downloadFile(String downloadUrl) async {
    try {
      AppLogger.debug('Downloading file from GitHub', downloadUrl);

      final response = await http.get(Uri.parse(downloadUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      return response.body;
    } catch (e, stack) {
      AppLogger.error('Failed to download file from GitHub', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Import all YAML rulesets from a GitHub directory
  ///
  /// Returns a map with success count, errors, and imported rulesets
  static Future<Map<String, dynamic>> importRulesetsFromGithub({
    required String githubUrl,
    required Future<int> Function(String yamlContent, String filename) onImport,
  }) async {
    try {
      final files = await listYamlFiles(githubUrl);

      if (files.isEmpty) {
        return {
          'success': false,
          'message': 'Keine YAML-Dateien gefunden',
          'imported': 0,
          'errors': <String>[],
        };
      }

      int successCount = 0;
      final errors = <String>[];
      final imported = <String>[];

      for (final file in files) {
        try {
          final content = await downloadFile(file['download_url'] as String);
          await onImport(content, file['name'] as String);
          successCount++;
          imported.add(file['name'] as String);
          AppLogger.info('Successfully imported ruleset', file['name']);
        } catch (e) {
          final errorMsg = '${file['name']}: $e';
          errors.add(errorMsg);
          AppLogger.error('Failed to import ruleset ${file['name']}', error: e);
        }
      }

      return {
        'success': successCount > 0,
        'message': successCount > 0
            ? 'Erfolgreich $successCount von ${files.length} Regelwerken importiert'
            : 'Keine Regelwerke konnten importiert werden',
        'imported': successCount,
        'total': files.length,
        'errors': errors,
        'importedFiles': imported,
      };
    } catch (e, stack) {
      AppLogger.error('Failed to import rulesets from GitHub', error: e, stackTrace: stack);
      return {
        'success': false,
        'message': 'Fehler beim Import: $e',
        'imported': 0,
        'errors': [e.toString()],
      };
    }
  }
}
