import 'package:flutter/material.dart';

/// Returns solid text/icon color that switches between:
/// - light mode: `Colors.black`
/// - dark mode: `Colors.white`
Color appTextColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.light
      ? Colors.black
      : Colors.white;
}

