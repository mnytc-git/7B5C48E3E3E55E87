import 'package:flutter/material.dart';

abstract final class AppConfig {
  static const String appName = 'MNYTC';

  static const String homepage = 'https://www.mnytc.eu';

  static const String allowedHost = 'www.mnytc.eu';

  static const String downloadFolderName = 'MNYTC';

  static const String androidPackageName = 'eu.mnytc.app';

  static const Color backgroundColor = Colors.black;

  static const Color foregroundColor = Colors.white;

  static const Color secondaryBackgroundColor = Color(0xFF171717);

  static Uri get homepageUri {
    return Uri.parse(homepage);
  }

  static bool isSecureUrl(Uri uri) {
    return uri.scheme.toLowerCase() == 'https';
  }

  static bool isMnytcUrl(Uri uri) {
    final String host = uri.host.toLowerCase();

    return host == allowedHost || host == 'mnytc.eu';
  }
}