import 'package:flutter/material.dart';

class VersionControlOverlay extends StatelessWidget {
  const VersionControlOverlay({super.key});

  static const int _versionYear = 2026;
  static const String _versionMonth = '01';
  static const String _versionWeekCode = 'B';
  static const String _versionDayCode = 'E';
  static const int _versionCommitNumber = 1;
  static const String _versionEnvironment = 'SIT';

  static const String versionLabel =
      'Ver. $_versionYear.$_versionMonth.'
      '$_versionWeekCode$_versionDayCode'
      '$_versionCommitNumber'
      '_$_versionEnvironment';

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
