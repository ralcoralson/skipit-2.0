import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0B0B0B); // Matte black base
  static const Color surface = Color(0xFF121212); // Secondary dark
  
  static const Color primary = Color(0xFF1D4EFF); // Accent Blue
  static const Color primaryGlow = Color(0xFF3B82F6); // Accent Glow
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA1A1AA);
  
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryGlow],
  );
}
