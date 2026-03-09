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
/// On web, also tries to load from same-origin /version.json so deployed app can show latest without rebuild.
class VersionService {
  static VersionData? _cached;

  static Future<VersionData> loadVersion() async {
    if (_cached != null) return _cached!;
    if (kIsWeb) {
      try {
        final uri = Uri.base.resolve('version.json');
        final response = await http.get(uri).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final map = json.decode(response.body) as Map<String, dynamic>?;
          if (map != null && _isCustomVersionFormat(map)) {
            _cached = VersionData.fromJson(map);
            return _cached!;
          }
        }
      } catch (_) {
        // Fall through to assets
      }
    }
    try {
      final s =
          await rootBundle.loadString('assets/data/version.json');
      final map = json.decode(s) as Map<String, dynamic>;
      _cached = VersionData.fromJson(map);
      return _cached!;
    } catch (_) {
      return VersionData.fallback;
    }
  }

  static void clearCache() {
    _cached = null;
  }

  /// True if the map looks like our version.json (YYYY.MM.[W][D][n]), not pubspec semver (e.g. 1.0.0).
  static bool _isCustomVersionFormat(Map<String, dynamic> map) {
    final v = map['version'];
    if (v == null || v is! String) return false;
    final s = v; // promoted to String
    return s.length >= 7 && s.startsWith('20');
  }
}
