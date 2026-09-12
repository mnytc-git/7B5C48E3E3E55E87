import 'package:flutter/material.dart';

import '../config/app_config.dart';

class OfflineView extends StatelessWidget {
  const OfflineView({
    required this.onRetry,
    super.key,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppConfig.backgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.wifi_off_rounded,
                color: AppConfig.foregroundColor,
                size: 56,
              ),
              const SizedBox(
                height: 20,
              ),
              const Text(
                'Tidak dapat membuka MNYTC',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppConfig.foregroundColor,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              const Text(
                'Periksa koneksi internet Anda, lalu coba kembali.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(
                height: 22,
              ),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text(
                  'Coba lagi',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
