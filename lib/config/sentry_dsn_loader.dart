import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'env.dart';

/// Loads Sentry DSN from compile-time `--dart-define` or, on web,
/// `sentry-config.json` written by CI into `build/web/`.
Future<String> resolveSentryDsn() async {
  final normalizedCompile = normalizeSentryDsn(compileTimeSentryDsn);
  if (normalizedCompile != null) {
    setRuntimeSentryDsn(normalizedCompile);
    return normalizedCompile;
  }
  if (compileTimeSentryDsn.isNotEmpty) {
    debugPrint(
      '[Sentry] Ignoring invalid compile-time DSN: $compileTimeSentryDsn',
    );
  }

  if (!kIsWeb) {
    return '';
  }

  try {
    final uri = Uri.base.resolve('sentry-config.json');
    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      debugPrint(
        '[Sentry] sentry-config.json returned HTTP ${response.statusCode}',
      );
      return '';
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      return '';
    }

    final dsn = (json['dsn'] as String?)?.trim() ?? '';
    final normalized = normalizeSentryDsn(dsn);
    if (normalized == null) {
      return '';
    }

    setRuntimeSentryDsn(normalized);
    debugPrint('[Sentry] Loaded DSN from sentry-config.json');
    return normalized;
  } catch (e) {
    debugPrint('[Sentry] Could not load sentry-config.json: $e');
    return '';
  }
}
