import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/map_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlayStyle);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Noisy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MapScreen(),
    );
  }
}
