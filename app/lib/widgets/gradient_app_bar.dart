import 'package:flutter/material.dart';

import '../theme.dart';

/// Gradient app bar helper — a plain AppBar with a gradient title treatment.
AppBar gradientAppBar(String title, {List<Widget>? actions, Widget? leading}) {
  return AppBar(
    title: ShaderMask(
      shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    actions: actions,
    leading: leading,
  );
}
