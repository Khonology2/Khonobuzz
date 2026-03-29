// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Sets `flutter-ready` on `<body>` for Cypress / E2E (CanvasKit has no stable DOM text).
void setFlutterReadyAttribute(bool ready) {
  html.document.body?.setAttribute('flutter-ready', ready ? 'true' : 'false');
}
