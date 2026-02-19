import 'dart:convert';
import 'package:flutter/services.dart';
 
/// Data model for commit information
class CommitInfo {
  final String author;
  final String message;
  final String timestamp;
 
  const CommitInfo({
    required this.author,
    required this.message,
    required this.timestamp,
  });
 
  factory CommitInfo.fromJson(Map<String, dynamic> json) {
    return CommitInfo(
      author: json['author'] as String,
      message: json['message'] as String,
      timestamp: json['timestamp'] as String,
    );
  }
}
 
/// Data model for commit data structure
class CommitData {
  final String version;
  final String generatedAt;
  final List<CommitInfo> commits;
  final int totalCommits;
  final String dateRange;
 
  const CommitData({
    required this.version,
    required this.generatedAt,
    required this.commits,
    required this.totalCommits,
    required this.dateRange,
  });
 
  factory CommitData.fromJson(Map<String, dynamic> json) {
    return CommitData(
      version: json['version'] as String,
      generatedAt: json['generated_at'] as String,
      commits: (json['commits'] as List<dynamic>?)
          ?.map((e) => CommitInfo.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      totalCommits: json['total_commits'] as int? ?? 0,
      dateRange: json['date_range'] as String? ?? '',
    );
  }
}
 
/// Service for loading and managing commit data
class CommitService {
  static CommitData? _cachedCommitData;
 
  /// Load commit data from assets, with caching
  static Future<CommitData> loadCommitData() async {
    if (_cachedCommitData != null) {
      return _cachedCommitData!;
    }
 
    try {
      final jsonString = await rootBundle.loadString('assets/data/daily-commits.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      _cachedCommitData = CommitData.fromJson(jsonData);
      return _cachedCommitData!;
    } catch (e) {
      // Return fallback data if loading fails
      return getFallbackCommitData();
    }
  }
 
  /// Get fallback commit data when loading fails (public for widget access)
  static CommitData getFallbackCommitData() {
    return CommitData(
      version: '2026.02.CD1.0.SIT',
      generatedAt: DateTime.now().toIso8601String(),
      commits: [
        CommitInfo(
          author: 'System',
          message: 'No commits found for today',
          timestamp: DateTime.now().toIso8601String(),
        ),
      ],
      totalCommits: 0,
      dateRange: DateTime.now().toIso8601String().split('T').first,
    );
  }
 
  /// Clear cached data (useful for testing or force refresh)
  static void clearCache() {
    _cachedCommitData = null;
  }
}
