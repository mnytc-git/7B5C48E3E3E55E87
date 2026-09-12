import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../config/app_config.dart';
import '../services/download_service.dart';
import '../widgets/loading_view.dart';
import '../widgets/offline_view.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({
    super.key,
  });

  @override
  State<WebViewScreen> createState() {
    return _WebViewScreenState();
  }
}

class _WebViewScreenState extends State<WebViewScreen> {
  final DownloadService _downloadService = DownloadService();

  InAppWebViewController? _webViewController;

  double _loadingProgress = 0;

  bool _hasMainFrameError = false;

  bool _isDownloading = false;

  Future<void> _showMessage(String message) async {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  Future<Map<String, String>> _createDownloadHeaders({
    required WebUri url,
    String? userAgent,
  }) async {
    final List<Cookie> cookies =
        await CookieManager.instance().getCookies(
      url: url,
    );

    final String cookieHeader = cookies
        .map(
          (Cookie cookie) {
            return '${cookie.name}=${cookie.value}';
          },
        )
        .join('; ');

    return <String, String>{
      if (cookieHeader.isNotEmpty)
        'Cookie': cookieHeader,
      if (userAgent != null && userAgent.isNotEmpty)
        'User-Agent': userAgent,
      'Referer': AppConfig.homepage,
    };
  }

  Future<void> _handleDownload(
    DownloadStartRequest request,
  ) async {
    if (_isDownloading) {
      await _showMessage(
        'Download lain sedang diproses.',
      );

      return;
    }

    final String downloadUrl = request.url.toString();

    if (downloadUrl.startsWith('blob:')) {
      await _showMessage(
        'Download blob memerlukan integrasi khusus dari website.',
      );

      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final String fileName =
          _downloadService.determineFileName(
        url: downloadUrl,
        contentDisposition: request.contentDisposition,
        suggestedFileName: request.suggestedFilename,
        mimeType: request.mimeType,
      );

      final Map<String, String> headers =
          await _createDownloadHeaders(
        url: request.url,
        userAgent: request.userAgent,
      );

      await _showMessage(
        'Mengunduh $fileName...',
      );

      final DownloadResult result =
          await _downloadService.download(
        url: downloadUrl,
        fileName: fileName,
        headers: headers,
      );

      await _showMessage(
        'File tersimpan di ${result.location}',
      );
    } catch (error) {
      await _showMessage(
        'Download gagal. Silakan coba lagi.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<bool> _handleAndroidBackButton() async {
    final InAppWebViewController? controller =
        _webViewController;

    if (controller == null) {
      return true;
    }

    final bool canGoBack = await controller.canGoBack();

    if (canGoBack) {
      await controller.goBack();

      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (
        bool didPop,
        Object? result,
      ) async {
        if (didPop) {
          return;
        }

        final bool shouldClose =
            await _handleAndroidBackButton();

        if (shouldClose && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppConfig.backgroundColor,
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(
                    AppConfig.homepage,
                  ),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  cacheEnabled: true,
                  supportZoom: false,
                  transparentBackground: false,
                  useOnDownloadStart: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  allowFileAccessFromFileURLs: false,
                  allowUniversalAccessFromFileURLs: false,
                  thirdPartyCookiesEnabled: true,
                  sharedCookiesEnabled: true,
                  useShouldOverrideUrlLoading: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  supportMultipleWindows: true,
                ),
                onWebViewCreated: (
                  InAppWebViewController controller,
                ) {
                  _webViewController = controller;
                },
                onLoadStart: (
                  InAppWebViewController controller,
                  WebUri? url,
                ) {
                  setState(() {
                    _hasMainFrameError = false;
                    _loadingProgress = 0;
                  });
                },
                onProgressChanged: (
                  InAppWebViewController controller,
                  int progress,
                ) {
                  setState(() {
                    _loadingProgress = progress / 100;
                  });
                },
                onLoadStop: (
                  InAppWebViewController controller,
                  WebUri? url,
                ) {
                  setState(() {
                    _loadingProgress = 1;
                  });
                },
                onReceivedError: (
                  InAppWebViewController controller,
                  WebResourceRequest request,
                  WebResourceError error,
                ) {
                  if (request.isForMainFrame ?? false) {
                    setState(() {
                      _hasMainFrameError = true;
                    });
                  }
                },
                onDownloadStartRequest: (
                  InAppWebViewController controller,
                  DownloadStartRequest request,
                ) async {
                  await _handleDownload(request);
                },
                onCreateWindow: (
                  InAppWebViewController controller,
                  CreateWindowAction action,
                ) async {
                  final WebUri? url = action.request.url;

                  if (url != null) {
                    await controller.loadUrl(
                      urlRequest: URLRequest(
                        url: url,
                      ),
                    );
                  }

                  return true;
                },
                shouldOverrideUrlLoading: (
                  InAppWebViewController controller,
                  NavigationAction navigationAction,
                ) async {
                  final WebUri? webUri =
                      navigationAction.request.url;

                  if (webUri == null) {
                    return NavigationActionPolicy.CANCEL;
                  }

                  final Uri uri = Uri.parse(
                    webUri.toString(),
                  );

                  if (uri.scheme == 'http') {
                    final Uri secureUri = uri.replace(
                      scheme: 'https',
                    );

                    await controller.loadUrl(
                      urlRequest: URLRequest(
                        url: WebUri(
                          secureUri.toString(),
                        ),
                      ),
                    );

                    return NavigationActionPolicy.CANCEL;
                  }

                  if (uri.scheme == 'https' ||
                      uri.scheme == 'about' ||
                      uri.scheme == 'data' ||
                      uri.scheme == 'blob') {
                    return NavigationActionPolicy.ALLOW;
                  }

                  return NavigationActionPolicy.CANCEL;
                },
              ),
              if (_loadingProgress < 1 &&
                  !_hasMainFrameError)
                LoadingView(
                  progress: _loadingProgress,
                ),
              if (_hasMainFrameError)
                OfflineView(
                  onRetry: () {
                    setState(() {
                      _hasMainFrameError = false;
                    });

                    unawaited(
                      _webViewController?.reload(),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}