import 'package:flutter_test/flutter_test.dart';
import 'package:mnytc/config/app_config.dart';

void main() {
  group('MNYTC application configuration', () {
    test('application name is configured', () {
      expect(
        AppConfig.appName,
        'MNYTC',
      );
    });

    test('homepage uses HTTPS', () {
      expect(
        AppConfig.homepageUri.scheme,
        'https',
      );

      expect(
        AppConfig.isSecureUrl(
          AppConfig.homepageUri,
        ),
        isTrue,
      );
    });

    test('homepage points to the MNYTC domain', () {
      expect(
        AppConfig.homepageUri.host,
        'www.mnytc.eu',
      );

      expect(
        AppConfig.isMnytcUrl(
          AppConfig.homepageUri,
        ),
        isTrue,
      );
    });

    test('download folder is configured', () {
      expect(
        AppConfig.downloadFolderName,
        'MNYTC',
      );

      expect(
        AppConfig.downloadFolderName,
        isNotEmpty,
      );
    });

    test('Android package name is valid', () {
      expect(
        AppConfig.androidPackageName,
        'eu.mnytc.app',
      );
    });
  });
}