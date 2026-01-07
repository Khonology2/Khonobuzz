import 'package:flutter/material.dart';

class VersionControlOverlay extends StatelessWidget {
  const VersionControlOverlay({super.key});

  static const String versionLabel = 'Ver. 2026.01.AC3_SIT';

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: 16,
      child: Text(
        versionLabel,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Colors.white70,
        ),
      ),
    );
  }
}
