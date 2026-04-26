import 'package:flutter/material.dart';

abstract class AppColors {
  // Primary
  static const Color royalBlue = Color(0xFF0047AB);
  static const Color royalBlueDark = Color(0xFF003380);
  static const Color royalBlueLight = Color(0xFF1A6FD4);

  // Accent
  static const Color crimson = Color(0xFFD2122E);
  static const Color crimsonDark = Color(0xFFAA0D24);
  static const Color crimsonLight = Color(0xFFE8304A);

  // Background
  static const Color darkBg = Color(0xFF050A18);
  static const Color darkSurface = Color(0xFF0D1426);
  static const Color darkCard = Color(0xFF111D35);

  // Glass
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassBorderLight = Color(0x66FFFFFF);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textMuted = Color(0x66FFFFFF);
  static const Color textDark = Color(0xFF0D1426);

  // Status
  static const Color success = Color(0xFF00C48C);
  static const Color warning = Color(0xFFFFBE21);
  static const Color error = Color(0xFFFF4D6A);

  // Donor Hero — Available state
  static const Color heroGreen = Color(0xFF00C48C);
  static const Color heroGreenDark = Color(0xFF009E72);
  static const Color heroGreenGlow = Color(0x4000C48C);
  static const Color urgentRed = Color(0xFFFF2D55);
  static const List<Color> heroGreenGradient = [
    Color(0xFF00C48C),
    Color(0xFF009E72),
  ];

  // Gradient stops
  static const List<Color> heroGradient = [
    Color(0xFF0047AB),
    Color(0xFF002F7A),
    Color(0xFF050A18),
  ];

  static const List<Color> cardGradient = [
    Color(0xFF1A6FD4),
    Color(0xFF0047AB),
  ];

  static const List<Color> crimsonGradient = [
    Color(0xFFE8304A),
    Color(0xFFD2122E),
  ];
}
