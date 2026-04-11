import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF001D3B);
  static const Color primaryContainer = Color(0xFF103257);
  static const Color onPrimary = Colors.white;
  
  // Backgrounds
  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Color(0xFFF7F9FC);
  static const Color surfaceContainer = Color(0xFFECEEF1);
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF434750);
  
  // Semantic Colors
  static const Color accentMint = Color(0xFFA3F69C); // Paid / Success
  static const Color errorRed = Color(0xFFBA1A1A); // Ghost Fees / Pending
  static const Color errorContainer = Color(0xFFFFDAD6);
  
  // Glassmorphic Colors
  static const Color glassBackground = Color(0x73FFFFFF); // 45% white
  static const Color glassBorder = Color(0x99FFFFFF); // 60% white
  static const Color glassHighlight = Color(0x66FFFFFF); // Glossy effect
  
  // Layout Colors
  static const Color sidebarBackground = Color(0xFFFFFFFF);
  static const Color cardShadow = Color(0x121F2687); // 7% blue/dark shadow
}
