import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Version data from version.json: YYYY.MM.[W][D][n] (W=week 1-4 A-D, D=weekday A-E Mon-Fri; Sat/Sun not counted).
class VersionData {
  final String version;
  final String lastFeatureCommit;
  final String featureDate;
  final int commitCountSinceFeature;

  const VersionData({
    required this.version,
    required this.lastFeatureCommit,
    required this.featureDate,
    required this.commitCountSinceFeature,
  });

  factory VersionData.fromJson(Map<String, dynamic> json) {
    return VersionData(
      version: json['version'] as String? ?? '2026.03.BA1',
      lastFeatureCommit:
          json['last_feature_commit'] as String? ?? '',
      featureDate: json['feature_date'] as String? ?? '',
      commitCountSinceFeature:
          json['commit_count_since_feature'] as int? ?? 0,
    );
  }

  static VersionData get fallback => VersionData(
        version: '2026.03.BA1',
        lastFeatureCommit: '',
        featureDate: '',
        commitCountSinceFeature: 1,
      );
}

/// Loads version from assets/data/version.json (updated by version-control workflow).
/// Tries network first (same-origin on web, then backend /api/version) so the app shows the latest version
/// without rebuild. Network result is not cached so the widget's periodic refresh picks up updates.
class VersionService {
  static VersionData? _cached;

  /// Backend endpoint that serves version.json (set in api_config or use baseUrl + '/api/version').
  static String? _versionUrl;

  /// After a 404 from backend we stop calling it for this session to avoid console spam.
  static bool _versionEndpointUnavailable = false;

  static Future<void> _debugLog(
    String hypothesisId,
    String location,
    String message,
    Map<String, dynamic> data,
  ) async {
    try {
      await http.post(
        Uri.parse('http://127.0.0.1:7331/ingest/cd82f6f5-b27f-4cc7-9949-8d39a3d82b54'),
        headers: const {
          'Content-Type': 'application/json',
          'X-Debug-Session-Id': '7ef484',
        },
        body: json.encode({
          'sessionId': '7ef484',
          'runId': 'pre-fix',
          'hypothesisId': hypothesisId,
          'location': location,
          'message': message,
          'data': data,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (_) {}
  }

  static set versionBaseUrl(String? baseUrl) {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      _versionUrl = baseUrl.endsWith('/') ? '${baseUrl}api/version' : '$baseUrl/api/version';
    } else {
      _versionUrl = null;
    }
    _versionEndpointUnavailable = false;
    // #region agent log
    _debugLog('H1', 'lib/services/version_service.dart:73', 'Configured version endpoint URL', {
      'baseUrl': baseUrl,
      'versionUrl': _versionUrl,
      'kIsWeb': kIsWeb,
    });
    // #endregion
  }

  static Future<VersionData> loadVersion() async {
    // #region agent log
    _debugLog('H4', 'lib/services/version_service.dart:82', 'Starting version load', {
      'uriBase': Uri.base.toString(),
      'versionUrl': _versionUrl,
      'endpointUnavailable': _versionEndpointUnavailable,
      'hasCachedAsset': _cached != null,
      'cachedVersion': _cached?.version,
      'kIsWeb': kIsWeb,
    });
    // #endregion
    // 1) Try network: same-origin (web) then backend. Do not cache so next refresh gets latest.
    if (kIsWeb) {
      try {
        final uri = Uri.base.resolve('version.json');
        final response = await http.get(uri).timeout(const Duration(seconds: 3));
        // #region agent log
        _debugLog('H2', 'lib/services/version_service.dart:95', 'Same-origin version.json response', {
          'url': uri.toString(),
          'statusCode': response.statusCode,
          'bodyLength': response.body.length,
        });
        // #endregion
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final map = json.decode(response.body) as Map<String, dynamic>?;
          if (map != null && _isCustomVersionFormat(map)) {
            // #region agent log
            _debugLog('H2', 'lib/services/version_service.dart:102', 'Using same-origin version.json', {
              'url': uri.toString(),
              'version': map['version'],
              'featureDate': map['feature_date'],
            });
            // #endregion
            return VersionData.fromJson(map);
          }
        }
      } catch (_) {
        // Fall through
      }
    }
    if (_versionUrl != null && !_versionEndpointUnavailable) {
      try {
        final uri = Uri.parse(_versionUrl!);
        final response = await http.get(uri).timeout(const Duration(seconds: 5));
        // #region agent log
        _debugLog('H3', 'lib/services/version_service.dart:117', 'Backend /api/version response', {
          'url': uri.toString(),
          'statusCode': response.statusCode,
          'bodyLength': response.body.length,
        });
        // #endregion
        if (response.statusCode == 404) {
          _versionEndpointUnavailable = true;
          // #region agent log
          _debugLog('H4', 'lib/services/version_service.dart:125', 'Marked version endpoint unavailable after 404', {
            'url': uri.toString(),
            'statusCode': response.statusCode,
          });
          // #endregion
        } else if (response.statusCode == 200 && response.body.isNotEmpty) {
          final map = json.decode(response.body) as Map<String, dynamic>?;
          if (map != null && _isCustomVersionFormat(map)) {
            // #region agent log
            _debugLog('H5', 'lib/services/version_service.dart:132', 'Using backend version payload', {
              'url': uri.toString(),
              'version': map['version'],
              'featureDate': map['feature_date'],
            });
            // #endregion
            return VersionData.fromJson(map);
          }
        }
      } catch (_) {
        // Fall through to assets
      }
    }

    // 2) Use cached asset result if we have it
    if (_cached != null) {
      // #region agent log
      _debugLog('H4', 'lib/services/version_service.dart:145', 'Using cached asset version', {
        'version': _cached!.version,
      });
      // #endregion
      return _cached!;
    }

    // 3) Load from assets and cache (only asset load is cached so app shows something when offline)
    try {
      final s = await rootBundle.loadString('assets/data/version.json');
      final map = json.decode(s) as Map<String, dynamic>;
      _cached = VersionData.fromJson(map);
      // #region agent log
      _debugLog('H4', 'lib/services/version_service.dart:156', 'Loaded bundled asset version', {
        'version': _cached!.version,
        'featureDate': _cached!.featureDate,
      });
      // #endregion
      return _cached!;
    } catch (_) {
      // #region agent log
      _debugLog('H5', 'lib/services/version_service.dart:163', 'Falling back to hardcoded version data', {
        'fallbackVersion': VersionData.fallback.version,
      });
      // #endregion
      return VersionData.fallback;
    }
  }

  static void clearCache() {
    _cached = null;
    _versionEndpointUnavailable = false;
  }

  /// True if the map looks like our version.json (YYYY.MM.[W][D][n]), not pubspec semver (e.g. 1.0.0).
  static bool _isCustomVersionFormat(Map<String, dynamic> map) {
    final v = map['version'];
    if (v == null || v is! String) return false;
    final s = v; // promoted to String
    return s.length >= 7 && s.startsWith('20');
  }
}
