import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'screens/webview_screen.dart';

class MnytcApp extends StatelessWidget {
  const MnytcApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppConfig.backgroundColor,
        canvasColor: AppConfig.backgroundColor,
        splashColor: Colors.white12,
        highlightColor: Colors.white10,
        colorScheme: const ColorScheme.dark(
          primary: AppConfig.foregroundColor,
          onPrimary: AppConfig.backgroundColor,
          surface: AppConfig.backgroundColor,
          onSurface: AppConfig.foregroundColor,
          error: Color(0xFFFF5252),
          onError: AppConfig.foregroundColor,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppConfig.foregroundColor,
          linearTrackColor: AppConfig.backgroundColor,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppConfig.foregroundColor,
            side: const BorderSide(
              color: AppConfig.foregroundColor,
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppConfig.secondaryBackgroundColor,
          contentTextStyle: TextStyle(
            color: AppConfig.foregroundColor,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const WebViewScreen(),
    );
  }
}