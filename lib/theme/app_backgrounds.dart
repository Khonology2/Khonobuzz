import 'package:flutter/material.dart';

/// Background image used behind full-screen content; switches with app brightness.
String appBackgroundAsset(BuildContext context) {
  return Theme.of(context).brightness == Brightness.light
      ? 'assets/images/light_mode_bg.png'
      : 'assets/images/nathi_bg.png';
}
