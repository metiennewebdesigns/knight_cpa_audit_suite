import 'package:flutter/material.dart';

class DT {
  // Brand
  static const Color brandNavy = Color(0xFF0E1524);

  // Surfaces (dark-first)
  static const Color darkBg = Color(0xFF0B1020);
  static const Color darkCard = Color(0xFF121A2E);
  static const Color lightBg = Color(0xFFF7F8FB);

  // Geometry
  static const double rSm = 12;
  static const double rMd = 16;
  static const double rLg = 20;

  static const EdgeInsets pagePad = EdgeInsets.all(16);
  static const EdgeInsets cardPad = EdgeInsets.all(16);

  // Shadows
  static List<BoxShadow> softShadow(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.10),
          blurRadius: 18,
          spreadRadius: 0,
          offset: const Offset(0, 10),
        ),
      ];
}