import 'package:flutter/material.dart';

import '../config/app_config.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({
    required this.progress,
    super.key,
  });

  final double progress;

  @override
  Widget build(BuildContext context) {
    final bool isIndeterminate = progress <= 0;

    return Align(
      alignment: Alignment.topCenter,
      child: LinearProgressIndicator(
        value: isIndeterminate ? null : progress,
        minHeight: 2,
        color: AppConfig.foregroundColor,
        backgroundColor: AppConfig.backgroundColor,
      ),
    );
  }
}