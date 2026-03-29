// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// [Uri.base] can omit the query on some static hosts; the real bar URL is authoritative.
bool browserUrlHasE2eAuth() {
  try {
    final uri = Uri.parse(html.window.location.href);
    if (uri.queryParameters['e2e'] == 'auth') return true;
    if (uri.fragment.contains('e2e=auth')) return true;
    return false;
  } catch (_) {
    return false;
  }
}
