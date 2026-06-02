import 'package:flutter/material.dart';

class AppTheme {
  // Dark theme colors
  static const Color darkBackground = Color(0xFF0F172A); // Deep slate
  static const Color charcoal = Color(0xFF1E293B);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);

  // Light theme colors
  static const Color lightBackground = Color(0xFFF8FAFC); // Soft slate light background
  static const Color lightSurface = Colors.white;
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Shared semantic colors (work brilliantly in both light and dark modes)
  static const Color tealAccent = Color(0xFF14B8A6); // Vibrant educational teal
  static const Color coralAction = Color(0xFFF43F5E); // Action coral
  static const Color emeraldGreen = Color(0xFF10B981); // Success emerald
  static const Color amberPremium = Color(0xFFF59E0B); // Premium amber/gold
  static const Color errorRed = Color(0xFFEF4444);

  // Helper method to resolve dynamic colors based on theme
  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? charcoal : lightSurface;
  }

  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textPrimary : lightTextPrimary;
  }

  static Color getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textSecondary : lightTextSecondary;
  }

  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? Colors.white12 : const Color(0xFFE2E8F0);
  }

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    primaryColor: tealAccent,
    dividerColor: Colors.white24,
    colorScheme: const ColorScheme.dark(
      primary: tealAccent,
      secondary: tealAccent,
      surface: charcoal,
      error: coralAction,
    ),
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: tealAccent,
        foregroundColor: textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: charcoal,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 4,
      shadowColor: Colors.black45,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: charcoal,
      selectedItemColor: tealAccent,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 20,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: charcoal,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    primaryColor: tealAccent,
    dividerColor: const Color(0xFFE2E8F0),
    colorScheme: const ColorScheme.light(
      primary: tealAccent,
      secondary: tealAccent,
      surface: lightSurface,
      error: coralAction,
    ),
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: lightTextPrimary, fontSize: 32, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: lightTextPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: lightTextSecondary, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: tealAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 4,
      shadowColor: Colors.black12,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: lightSurface,
      selectedItemColor: tealAccent,
      unselectedItemColor: lightTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 10,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}
