import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'DiabeticAI';
  static const String appSubtitle = 'AI-Powered Early Detection of Diabetes and Personalized Healthcare';
  static const String copyrightFooter = '© 2026 DiabeticAI. All rights reserved.';

  // Color Palette
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryBlueDark = Color(0xFF1D4ED8);
  static const Color primaryBlueLight = Color(0xFFEFF6FF);
  
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentCyanLight = Color(0xFFECFEFF);

  static const Color bgWhite = Color(0xFFFFFFFF);
  static const Color bgLightSlate = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color dividerColor = Color(0xFFE2E8F0);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color statusHealthy = Color(0xFF10B981);
  static const Color statusHealthyBg = Color(0xFFECFDF5);
  static const Color statusPrediabetic = Color(0xFFF59E0B);
  static const Color statusPrediabeticBg = Color(0xFFFFFBEB);
  static const Color statusDiabetic = Color(0xFFEF4444);
  static const Color statusDiabeticBg = Color(0xFFFEF2F2);

  // FastAPI REST API Base URL
  // Default: http://10.0.2.2:8000 for Android Emulator (automatically mapped to localhost:8000 on Web/Desktop).
  // When running start_cf_tunnel.py, this line is automatically updated with the live Cloudflare tunnel URL.
  static const String baseUrl = "http://10.0.2.2:8000";
}
