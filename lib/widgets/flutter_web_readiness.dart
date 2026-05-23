import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../flutter_ready_body_stub.dart'
    if (dart.library.html) '../flutter_ready_body_web.dart' as flutter_ready_body;

/// Web: marks `<body flutter-ready="true">` after layout + semantics have had a frame to attach.
/// Uses two [addPostFrameCallback] passes so CanvasKit semantics often lag one frame behind paint.
class FlutterWebReadiness extends StatefulWidget {
  const FlutterWebReadiness({super.key, required this.child});

  final Widget child;

  @override
  State<FlutterWebReadiness> createState() => _FlutterWebReadinessState();
}

class _FlutterWebReadinessState extends State<FlutterWebReadiness> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    flutter_ready_body.setFlutterReadyAttribute(false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Second frame: semantics tree is typically populated after first paint (CanvasKit).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        flutter_ready_body.setFlutterReadyAttribute(true);
      });
    });
  }

  @override
  void dispose() {
    if (kIsWeb) {
      flutter_ready_body.setFlutterReadyAttribute(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
