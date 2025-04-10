import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();
  
  // App theme
  static ThemeData get darkTheme => ThemeData.dark().copyWith(
    scaffoldBackgroundColor: Colors.black,
    primaryColor: Colors.blue,
    colorScheme: ColorScheme.dark(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
      surface: Colors.grey[900]!,
      background: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    ),
  );
  
  // System UI overlay style
  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  );
  
  // Text styles
  static const TextStyle appBarTitle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w600,
    fontSize: 22,
  );
  
  static const TextStyle dialogTitle = TextStyle(
    color: Colors.white,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle dialogContent = TextStyle(
    color: Colors.white,
    fontSize: 16,
  );
  
  // Button styles
  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  );
  
  static ButtonStyle get secondaryButton => TextButton.styleFrom(
    foregroundColor: Colors.white70,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  );
  
  static ButtonStyle get closeButton => TextButton.styleFrom(
    foregroundColor: Colors.white,
    backgroundColor: Colors.blue.withOpacity(0.2),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  );
  
  static ButtonStyle get errorButton => TextButton.styleFrom(
    foregroundColor: Colors.white,
    backgroundColor: Colors.redAccent.withOpacity(0.2),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  );
  
  // Input decoration
  static InputDecoration inputDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.blue.withOpacity(0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.blue),
    ),
  );
  
  // Container decorations
  static BoxDecoration get dialogDecoration => BoxDecoration(
    color: Colors.black.withOpacity(0.8),
    borderRadius: BorderRadius.circular(15),
    boxShadow: [
      BoxShadow(
        color: Colors.white.withOpacity(0.1),
        blurRadius: 10,
        spreadRadius: 1,
      )
    ]
  );
  
  static BoxDecoration get errorDialogDecoration => BoxDecoration(
    color: Colors.black.withOpacity(0.8),
    borderRadius: BorderRadius.circular(15),
    boxShadow: [
      BoxShadow(
        color: Colors.redAccent.withOpacity(0.2),
        blurRadius: 10,
        spreadRadius: 1,
      )
    ]
  );
  
  static BoxDecoration get floatingButtonDecoration => BoxDecoration(
    color: Colors.black.withOpacity(0.6),
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );
} 