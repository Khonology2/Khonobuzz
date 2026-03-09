import 'dart:convert';
import 'package:flutter/services.dart';

/// Version data from version.json: YYYY.MM.[W][D][n] (W=week A-E, D=weekday A-E Mon-Fri, n=commit count).
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
class VersionService {
  static VersionData? _cached;

  static Future<VersionData> loadVersion() async {
    if (_cached != null) return _cached!;
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
}
