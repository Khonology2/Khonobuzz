import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Keeps Render module backends warm while the user is logged in.
/// Call [start] after successful login and [stop] on logout.
class ModulesPingService {
  ModulesPingService._();

  static Timer? _timer;

  /// Base URLs (no trailing slash required).
  static const List<String> moduleBackendBaseUrls = [
    'https://personal-development-backend.onrender.com',
    'https://recruitment-api-zovg.onrender.com',
    'https://lukens-wp8w.onrender.com',
    'https://flow-space.onrender.com',
    'https://resource-capacity.onrender.com',
  ];

  /// How often to GET each backend while logged in (Render free tier sleeps ~15 min idle).
  static const Duration pingInterval = Duration(minutes: 4);

  static const Duration _requestTimeout = Duration(seconds: 12);

  static Uri _uriFor(String base, String path) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return Uri.parse('$b$path');
  }

  static Future<void> _pingOneBase(String base) async {
    const paths = ['/', '/health', '/api/health', '/api'];
    for (final path in paths) {
      try {
        final uri = _uriFor(base, path);
        final response = await http.get(uri).timeout(_requestTimeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return;
        }
        if (response.statusCode < 500) {
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ModulesPing] $base$path: $e');
        }
      }
    }
  }

  @visibleForTesting
  static Future<void> pingOnce() async {
    await Future.wait(
      moduleBackendBaseUrls.map(_pingOneBase),
      eagerError: false,
    );
  }

  /// Call after login success. Idempotent: restarts the timer if already running.
  static void start() {
    if (kIsWeb) {
      // Browser enforces CORS; cross-origin GETs to module backends fail and flood the console.
      return;
    }
    stop();
    unawaited(pingOnce());
    _timer = Timer.periodic(pingInterval, (_) {
      unawaited(pingOnce());
    });
    if (kDebugMode) {
      debugPrint('[ModulesPing] Started periodic warmup (${pingInterval.inMinutes} min)');
    }
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    if (kDebugMode) {
      debugPrint('[ModulesPing] Stopped');
    }
  }
}
