import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

class DownloadResult {
  const DownloadResult({
    required this.fileName,
    required this.location,
  });

  final String fileName;

  final String location;
}

class DownloadService {
  DownloadService({
    Dio? dio,
  }) : _dio = dio ?? Dio();

  static const MethodChannel _androidDownloadChannel =
      MethodChannel('eu.mnytc.app/downloads');

  final Dio _dio;

  String createSafeFileName(String value) {
    final String sanitized = value
        .replaceAll(
          RegExp(r'[\\/:*?"<>|]'),
          '_',
        )
        .trim();

    if (sanitized.isEmpty) {
      return 'download_${DateTime.now().millisecondsSinceEpoch}';
    }

    return sanitized;
  }

  String determineFileName({
    required String url,
    String? contentDisposition,
    String? suggestedFileName,
    String? mimeType,
  }) {
    if (suggestedFileName != null &&
        suggestedFileName.trim().isNotEmpty) {
      return createSafeFileName(suggestedFileName);
    }

    final RegExp contentDispositionPattern = RegExp(
      r'''filename\*?=(?:UTF-8''|["'])?([^"';]+)''',
      caseSensitive: false,
    );

    final RegExpMatch? contentDispositionMatch =
        contentDispositionPattern.firstMatch(
      contentDisposition ?? '',
    );

    if (contentDispositionMatch != null) {
      final String encodedFileName =
          contentDispositionMatch.group(1) ?? '';

      return createSafeFileName(
        Uri.decodeFull(encodedFileName),
      );
    }

    final Uri? uri = Uri.tryParse(url);

    if (uri != null) {
      final Iterable<String> pathSegments = uri.pathSegments.where(
        (String segment) => segment.trim().isNotEmpty,
      );

      if (pathSegments.isNotEmpty) {
        final String urlFileName = pathSegments.last;

        if (urlFileName.contains('.')) {
          return createSafeFileName(urlFileName);
        }
      }
    }

    final String extension = _extensionFromMimeType(mimeType);

    return createSafeFileName(
      'download_${DateTime.now().millisecondsSinceEpoch}$extension',
    );
  }

  String _extensionFromMimeType(String? mimeType) {
    switch (mimeType?.toLowerCase()) {
      case 'application/pdf':
        return '.pdf';

      case 'application/zip':
      case 'application/x-zip-compressed':
        return '.zip';

      case 'application/json':
        return '.json';

      case 'text/plain':
        return '.txt';

      case 'text/csv':
        return '.csv';

      case 'image/png':
        return '.png';

      case 'image/jpeg':
      case 'image/jpg':
        return '.jpg';

      case 'image/webp':
        return '.webp';

      case 'video/mp4':
        return '.mp4';

      case 'audio/mpeg':
        return '.mp3';

      default:
        return '';
    }
  }

  Future<DownloadResult> download({
    required String url,
    required String fileName,
    Map<String, String>? headers,
    void Function(int received, int total)? onProgress,
  }) async {
    final String safeFileName = createSafeFileName(fileName);

    if (Platform.isAndroid) {
      return _downloadWithAndroidDownloadManager(
        url: url,
        fileName: safeFileName,
        headers: headers ?? <String, String>{},
      );
    }

    return _downloadWithDio(
      url: url,
      fileName: safeFileName,
      headers: headers ?? <String, String>{},
      onProgress: onProgress,
    );
  }

  Future<DownloadResult> _downloadWithAndroidDownloadManager({
    required String url,
    required String fileName,
    required Map<String, String> headers,
  }) async {
    final String? location =
        await _androidDownloadChannel.invokeMethod<String>(
      'download',
      <String, dynamic>{
        'url': url,
        'fileName': fileName,
        'folderName': AppConfig.downloadFolderName,
        'headers': headers,
      },
    );

    return DownloadResult(
      fileName: fileName,
      location: location ??
          'Download/${AppConfig.downloadFolderName}/$fileName',
    );
  }

  Future<DownloadResult> _downloadWithDio({
    required String url,
    required String fileName,
    required Map<String, String> headers,
    void Function(int received, int total)? onProgress,
  }) async {
    final Directory baseDirectory =
        await _getDesktopOrAppleDirectory();

    final Directory mnytcDirectory = Directory(
      path.join(
        baseDirectory.path,
        AppConfig.downloadFolderName,
      ),
    );

    if (!await mnytcDirectory.exists()) {
      await mnytcDirectory.create(
        recursive: true,
      );
    }

    final String destinationPath = path.join(
      mnytcDirectory.path,
      fileName,
    );

    await _dio.download(
      url,
      destinationPath,
      options: Options(
        headers: headers,
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 10),
        sendTimeout: const Duration(minutes: 2),
      ),
      onReceiveProgress: onProgress,
    );

    return DownloadResult(
      fileName: fileName,
      location: destinationPath,
    );
  }

  Future<Directory> _getDesktopOrAppleDirectory() async {
    if (Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux) {
      final Directory? downloadsDirectory =
          await getDownloadsDirectory();

      if (downloadsDirectory != null) {
        return downloadsDirectory;
      }
    }

    return getApplicationDocumentsDirectory();
  }
}