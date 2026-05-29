import 'package:flutter/material.dart';

class AppTheme {
  // ═══════════════════════════════════════════
  // الألوان الأساسية — مطابقة للصور تماماً
  // ═══════════════════════════════════════════

  // خلفيات
  static const Color bgPrimary   = Color(0xFF000000); // أسود كامل
  static const Color bgSecondary = Color(0xFF0A0A0A); // أسود داكن جداً
  static const Color bgCard      = Color(0xFF111111); // بطاقات
  static const Color bgMessage   = Color(0xFF1A1A1A); // فقاعات الرسائل

  // الألوان التكتيكية
  static const Color accentCyan   = Color(0xFF00E5FF); // سيان — اللون الرئيسي
  static const Color accentGreen  = Color(0xFF00FF88); // أخضر — متصل / آمن
  static const Color accentRed    = Color(0xFFFF1744); // أحمر — طوارئ / SOS
  static const Color accentOrange = Color(0xFFFF6D00); // برتقالي — تحذير
  static const Color accentYellow = Color(0xFFFFD600); // أصفر — تنبيه

  // ألوان الرسائل
  static const Color bubbleMe     = Color(0xFF1565C0); // أزرق غامق — رسائلي
  static const Color bubbleOther  = Color(0xFF1C1C1C); // رمادي داكن — رسائل الآخرين
  static const Color bubbleSOS    = Color(0xFF8B0000); // أحمر داكن — SOS

  // ألوان النص
  static const Color textPrimary   = Color(0xFFFFFFFF); // أبيض كامل
  static const Color textSecondary = Color(0xFF8A8A8A); // رمادي
  static const Color textMuted     = Color(0xFF444444); // باهت جداً
  static const Color textCyan      = Color(0xFF00E5FF); // سيان
  static const Color textGreen     = Color(0xFF00FF88); // أخضر
  static const Color textRed       = Color(0xFFFF1744); // أحمر
  static const Color textYellow    = Color(0xFFFFD600); // أصفر

  // ألوان الرادار
  static const Color radarBg       = Color(0xFF001A00); // أخضر شديد الداكن
  static const Color radarGrid     = Color(0xFF00AA00); // أخضر رادار
  static const Color radarSweep    = Color(0xFF00FF00); // أخضر ساطع للمسح
  static const Color radarDot      = Color(0xFF00FF88); // نقاط الأجهزة

  // ألوان Topology
  static const Color nodeMe        = Color(0xFF00E5FF); // سيان — أنا
  static const Color nodeRescuer   = Color(0xFF00E5FF); // سيان — منقذ
  static const Color nodeVictim    = Color(0xFFFF1744); // أحمر — ضحية
  static const Color nodeOffline   = Color(0xFF333333); // رمادي — غير متصل
  static const Color nodeGO        = Color(0xFF00FF88); // أخضر — Group Owner
  static const Color edgeNormal    = Color(0xFF00E5FF); // خط اتصال عادي
  static const Color edgeBridge    = Color(0xFF8A2BE2); // بنفسجي — Bridge

  // ═══════════════════════════════════════════
  // الـ Theme الكامل
  // ═══════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPrimary,
      primaryColor: accentCyan,
      colorScheme: const ColorScheme.dark(
        primary: accentCyan,
        secondary: accentGreen,
        error: accentRed,
        background: bgPrimary,
        surface: bgSecondary,
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: bgPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 1.5,
        ),
        iconTheme: IconThemeData(color: accentCyan),
        surfaceTintColor: Colors.transparent,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgSecondary,
        selectedItemColor: accentCyan,
        unselectedItemColor: textMuted,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 11,
          letterSpacing: 1,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 1,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 13,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 11,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 10,
          color: textMuted,
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSecondary,
        hintStyle: const TextStyle(
          color: textMuted,
          fontFamily: 'SpaceMono',
          fontSize: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1A1A1A),
        thickness: 1,
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Gradients المستخدمة
  // ═══════════════════════════════════════════
  static const LinearGradient sosGradient = LinearGradient(
    colors: [Color(0xFF8B0000), Color(0xFF5C0000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF006064)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient radarGradient = RadialGradient(
    colors: [
      radarBg.withOpacity(0.95),
      radarBg.withOpacity(0.85),
    ],
    center: Alignment.center,
  ) as LinearGradient;

  // ═══════════════════════════════════════════
  // Box Shadows المستخدمة
  // ═══════════════════════════════════════════
  static List<BoxShadow> get cyanGlow => [
    BoxShadow(
      color: accentCyan.withOpacity(0.4),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> get redGlow => [
    BoxShadow(
      color: accentRed.withOpacity(0.6),
      blurRadius: 25,
      spreadRadius: 5,
    ),
  ];

  static List<BoxShadow> get greenGlow => [
    BoxShadow(
      color: accentGreen.withOpacity(0.4),
      blurRadius: 15,
      spreadRadius: 2,
    ),
  ];
}
