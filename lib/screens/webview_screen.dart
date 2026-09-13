import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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

  WebViewEnvironment? _windowsWebViewEnvironment;

  double _loadingProgress = 0;

  bool _isInitializing = true;

  bool _hasMainFrameError = false;

  bool _isDownloading = false;

  bool _isWebView2Missing = false;

  String? _lastErrorMessage;

  @override
  void initState() {
    super.initState();

    unawaited(
      _initializeWebView(),
    );
  }

  Future<void> _initializeWebView() async {
    try {
      if (Platform.isWindows) {
        await _initializeWindowsWebViewEnvironment();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _isWebView2Missing = false;
        _lastErrorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _isWebView2Missing = Platform.isWindows;
        _lastErrorMessage = error.toString();
      });
    }
  }

  Future<void> _initializeWindowsWebViewEnvironment() async {
    final String? availableVersion =
        await WebViewEnvironment.getAvailableVersion();

    if (availableVersion == null ||
        availableVersion.trim().isEmpty) {
      throw StateError(
        'Microsoft Edge WebView2 Runtime tidak ditemukan.',
      );
    }

    final Directory applicationSupportDirectory =
        await getApplicationSupportDirectory();

    final Directory webViewDataDirectory = Directory(
      path.join(
        applicationSupportDirectory.path,
        AppConfig.appName,
        'WebView2',
      ),
    );

    if (!await webViewDataDirectory.exists()) {
      await webViewDataDirectory.create(
        recursive: true,
      );
    }

    _windowsWebViewEnvironment =
        await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(
        userDataFolder: webViewDataDirectory.path,
      ),
    );
  }

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
      if (userAgent != null &&
          userAgent.trim().isNotEmpty)
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
        'File blob memerlukan integrasi download khusus.',
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
        'Download gagal: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<bool> _handleBackButton() async {
    final InAppWebViewController? controller =
        _webViewController;

    if (controller == null) {
      return true;
    }

    final bool canGoBack = await controller.canGoBack();

    if (!canGoBack) {
      return true;
    }

    await controller.goBack();

    return false;
  }

  Future<void> _retry() async {
    if (_isWebView2Missing) {
      setState(() {
        _isInitializing = true;
        _isWebView2Missing = false;
        _lastErrorMessage = null;
      });

      await _initializeWebView();

      return;
    }

    setState(() {
      _hasMainFrameError = false;
      _lastErrorMessage = null;
      _loadingProgress = 0;
    });

    final InAppWebViewController? controller =
        _webViewController;

    if (controller == null) {
      await _initializeWebView();

      return;
    }

    await controller.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(
          AppConfig.homepage,
        ),
      ),
    );
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
            await _handleBackButton();

        if (shouldClose && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppConfig.backgroundColor,
        body: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const ColoredBox(
        color: AppConfig.backgroundColor,
        child: Center(
          child: CircularProgressIndicator(
            color: AppConfig.foregroundColor,
          ),
        ),
      );
    }

    if (_isWebView2Missing) {
      return _buildWebView2MissingView();
    }

    return Stack(
      children: <Widget>[
        InAppWebView(
          webViewEnvironment:
              _windowsWebViewEnvironment,
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
            if (!mounted) {
              return;
            }

            setState(() {
              _hasMainFrameError = false;
              _lastErrorMessage = null;
              _loadingProgress = 0;
            });
          },
          onProgressChanged: (
            InAppWebViewController controller,
            int progress,
          ) {
            if (!mounted) {
              return;
            }

            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onLoadStop: (
            InAppWebViewController controller,
            WebUri? url,
          ) {
            if (!mounted) {
              return;
            }

            setState(() {
              _loadingProgress = 1;
              _hasMainFrameError = false;
              _lastErrorMessage = null;
            });
          },
          onReceivedError: (
            InAppWebViewController controller,
            WebResourceRequest request,
            WebResourceError error,
          ) {
            final bool isMainFrame =
                request.isForMainFrame ?? false;

            if (!isMainFrame || !mounted) {
              return;
            }

            setState(() {
              _hasMainFrameError = true;
              _lastErrorMessage =
                  '${error.type}: ${error.description}';
            });
          },
          onReceivedHttpError: (
            InAppWebViewController controller,
            WebResourceRequest request,
            WebResourceResponse response,
          ) {
            final bool isMainFrame =
                request.isForMainFrame ?? false;

            if (!isMainFrame || !mounted) {
              return;
            }

            final int? statusCode =
                response.statusCode;

            if (statusCode == null ||
                statusCode < 400) {
              return;
            }

            setState(() {
              _hasMainFrameError = true;
              _lastErrorMessage =
                  'HTTP $statusCode';
            });
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

            if (url == null) {
              return false;
            }

            await controller.loadUrl(
              urlRequest: URLRequest(
                url: url,
              ),
            );

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

            const Set<String> allowedSchemes =
                <String>{
              'https',
              'about',
              'data',
              'blob',
            };

            if (allowedSchemes.contains(uri.scheme)) {
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
          _buildConnectionErrorView(),
      ],
    );
  }

  Widget _buildConnectionErrorView() {
    return Stack(
      children: <Widget>[
        OfflineView(
          onRetry: () {
            unawaited(
              _retry(),
            );
          },
        ),
        if (_lastErrorMessage != null)
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Text(
              _lastErrorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWebView2MissingView() {
    return ColoredBox(
      color: AppConfig.backgroundColor,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.web_asset_off_rounded,
                color: AppConfig.foregroundColor,
                size: 56,
              ),
              const SizedBox(
                height: 20,
              ),
              const Text(
                'Microsoft Edge WebView2 diperlukan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppConfig.foregroundColor,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              const Text(
                'Pasang atau perbarui Microsoft Edge WebView2 Runtime, lalu buka kembali aplikasi MNYTC.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              if (_lastErrorMessage != null) ...<Widget>[
                const SizedBox(
                  height: 16,
                ),
                Text(
                  _lastErrorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(
                height: 24,
              ),
              OutlinedButton.icon(
                onPressed: () {
                  unawaited(
                    _retry(),
                  );
                },
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text(
                  'Periksa kembali',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}