import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
      version: json['version'] as String? ?? '2026.03.AB1',
      lastFeatureCommit: json['last_feature_commit'] as String? ?? '',
      featureDate: json['feature_date'] as String? ?? '',
      commitCountSinceFeature: json['commit_count_since_feature'] as int? ?? 0,
    );
  }

  static VersionData get fallback => VersionData(
    version: '2026.03.AB1',
    lastFeatureCommit: '',
    featureDate: '',
    commitCountSinceFeature: 1,
  );
}

/// Loads version from assets/data/version.json (updated by version-control workflow).
/// Tries network (same-origin on web, then backend /api/version) until a valid payload is obtained,
/// then keeps it in memory and [SharedPreferences] so /api/version is not called repeatedly.
class VersionService {
  /// Bundled asset parse cache (offline fallback).
  static VersionData? _cached;

  /// Last successful network or persisted payload; reused for all subsequent loads.
  static VersionData? _networkCached;

  static Future<VersionData>? _inFlightLoad;

  static const String _prefsKey = 'version_service_network_payload_v1';

  /// Safety cap on HTTP attempts per process if we never get a valid payload.
  static const int _maxNetworkAttempts = 3;
  static int _networkAttemptCount = 0;

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
    if (!kDebugMode) {
      return;
    }
    try {
      await http.post(
        Uri.parse(
          'http://127.0.0.1:7331/ingest/cd82f6f5-b27f-4cc7-9949-8d39a3d82b54',
        ),
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
      _versionUrl = baseUrl.endsWith('/')
          ? '${baseUrl}api/version'
          : '$baseUrl/api/version';
    } else {
      _versionUrl = null;
    }
    _versionEndpointUnavailable = false;
    // #region agent log
    _debugLog(
      'H1',
      'lib/services/version_service.dart:73',
      'Configured version endpoint URL',
      {'baseUrl': baseUrl, 'versionUrl': _versionUrl, 'kIsWeb': kIsWeb},
    );
    // #endregion
  }

  static Future<void> _persistNetworkVersion(VersionData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        json.encode({
          'version': data.version,
          'last_feature_commit': data.lastFeatureCommit,
          'feature_date': data.featureDate,
          'commit_count_since_feature': data.commitCountSinceFeature,
        }),
      );
    } catch (_) {}
  }

  static Future<VersionData> loadVersion() async {
    if (_networkCached != null) {
      return _networkCached!;
    }
    if (_inFlightLoad != null) {
      return _inFlightLoad!;
    }
    _inFlightLoad = _loadVersionImpl();
    try {
      return await _inFlightLoad!;
    } finally {
      _inFlightLoad = null;
    }
  }

  static Future<VersionData> _loadVersionImpl() async {
    // #region agent log
    _debugLog(
      'H4',
      'lib/services/version_service.dart:82',
      'Starting version load',
      {
        'uriBase': Uri.base.toString(),
        'versionUrl': _versionUrl,
        'endpointUnavailable': _versionEndpointUnavailable,
        'hasCachedAsset': _cached != null,
        'cachedVersion': _cached?.version,
        'kIsWeb': kIsWeb,
      },
    );
    // #endregion

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = json.decode(jsonStr) as Map<String, dynamic>?;
        if (map != null && _isCustomVersionFormat(map)) {
          _networkCached = VersionData.fromJson(map);
          return _networkCached!;
        }
      }
    } catch (_) {}

    // 1) Try network: same-origin (web) then backend (at most [_maxNetworkAttempts] HTTP tries per process).
    if (kIsWeb) {
      try {
        final uri = Uri.base.resolve('version.json');
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 3));
        // #region agent log
        _debugLog(
          'H2',
          'lib/services/version_service.dart:95',
          'Same-origin version.json response',
          {
            'url': uri.toString(),
            'statusCode': response.statusCode,
            'bodyLength': response.body.length,
          },
        );
        // #endregion
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final map = json.decode(response.body) as Map<String, dynamic>?;
          if (map != null && _isCustomVersionFormat(map)) {
            // #region agent log
            _debugLog(
              'H2',
              'lib/services/version_service.dart:102',
              'Using same-origin version.json',
              {
                'url': uri.toString(),
                'version': map['version'],
                'featureDate': map['feature_date'],
              },
            );
            // #endregion
            final data = VersionData.fromJson(map);
            _networkCached = data;
            await _persistNetworkVersion(data);
            return data;
          }
        }
      } catch (_) {
        // Fall through
      }
    }
    if (_versionUrl != null &&
        !_versionEndpointUnavailable &&
        _networkAttemptCount < _maxNetworkAttempts) {
      try {
        _networkAttemptCount++;
        final uri = Uri.parse(_versionUrl!);
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 5));
        // #region agent log
        _debugLog(
          'H3',
          'lib/services/version_service.dart:117',
          'Backend /api/version response',
          {
            'url': uri.toString(),
            'statusCode': response.statusCode,
            'bodyLength': response.body.length,
          },
        );
        // #endregion
        if (response.statusCode == 404) {
          _versionEndpointUnavailable = true;
          // #region agent log
          _debugLog(
            'H4',
            'lib/services/version_service.dart:125',
            'Marked version endpoint unavailable after 404',
            {'url': uri.toString(), 'statusCode': response.statusCode},
          );
          // #endregion
        } else if (response.statusCode == 200 && response.body.isNotEmpty) {
          final map = json.decode(response.body) as Map<String, dynamic>?;
          if (map != null && _isCustomVersionFormat(map)) {
            // #region agent log
            _debugLog(
              'H5',
              'lib/services/version_service.dart:132',
              'Using backend version payload',
              {
                'url': uri.toString(),
                'version': map['version'],
                'featureDate': map['feature_date'],
              },
            );
            // #endregion
            final data = VersionData.fromJson(map);
            _networkCached = data;
            await _persistNetworkVersion(data);
            return data;
          }
        }
      } catch (_) {
        // Fall through to assets
      }
    }

    // 2) Use cached asset result if we have it
    if (_cached != null) {
      // #region agent log
      _debugLog(
        'H4',
        'lib/services/version_service.dart:145',
        'Using cached asset version',
        {'version': _cached!.version},
      );
      // #endregion
      _networkCached = _cached;
      await _persistNetworkVersion(_cached!);
      return _cached!;
    }

    // 3) Load from assets and cache (offline / no API)
    try {
      final s = await rootBundle.loadString('assets/data/version.json');
      final map = json.decode(s) as Map<String, dynamic>;
      _cached = VersionData.fromJson(map);
      // #region agent log
      _debugLog(
        'H4',
        'lib/services/version_service.dart:156',
        'Loaded bundled asset version',
        {'version': _cached!.version, 'featureDate': _cached!.featureDate},
      );
      // #endregion
      _networkCached = _cached;
      await _persistNetworkVersion(_cached!);
      return _cached!;
    } catch (_) {
      // #region agent log
      _debugLog(
        'H5',
        'lib/services/version_service.dart:163',
        'Falling back to hardcoded version data',
        {'fallbackVersion': VersionData.fallback.version},
      );
      // #endregion
      _networkCached = VersionData.fallback;
      await _persistNetworkVersion(VersionData.fallback);
      return VersionData.fallback;
    }
  }

  /// Clears bundled-asset cache only. Does not clear the last known API version
  /// (see [clearNetworkVersionCache]).
  static void clearCache() {
    _cached = null;
    _versionEndpointUnavailable = false;
  }

  /// Clears persisted and in-memory network version (e.g. after logout or for tests).
  static Future<void> clearNetworkVersionCache() async {
    _networkCached = null;
    _cached = null;
    _networkAttemptCount = 0;
    _inFlightLoad = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  /// True if the map looks like our version.json (YYYY.MM.[W][D][n]), not pubspec semver (e.g. 1.0.0).
  static bool _isCustomVersionFormat(Map<String, dynamic> map) {
    final v = map['version'];
    if (v == null || v is! String) return false;
    final s = v; // promoted to String
    return s.length >= 7 && s.startsWith('20');
  }
}
