import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../bridge/shell_bridge.dart';

/// WebView widget that loads a module URL and wires up the JS bridge.
///
/// Bridge flow (from POC — proven pattern):
///   JS calls: shellBridge.postMessage(JSON.stringify({ id, method, args }))
///   Flutter receives in [_handleBridgeMessage], routes to [ShellBridge.handleCall]
///   Flutter responds via: window.dispatchEvent(new CustomEvent('flutterResponse', ...))
///   JS resolves the Promise in bridge_helper.js
class ModuleWebView extends StatefulWidget {
  final String url;
  final Map<String, dynamic> authContext;

  const ModuleWebView({
    Key? key,
    required this.url,
    this.authContext = const {},
  }) : super(key: key);

  @override
  State<ModuleWebView> createState() => _ModuleWebViewState();
}

class _ModuleWebViewState extends State<ModuleWebView> {
  late final WebViewController _controller;
  late final ShellBridge _bridge;
  bool _pageLoaded = false;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _wasOnline = false;

  @override
  void initState() {
    super.initState();
    _bridge = ShellBridge(context);
    _initWebView();
    _subscribeToConnectivity();
  }

  void _initWebView() {
    // Platform-specific WebView params (from POC — prevents runtime crash)
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) => print('[WebView] Loading: $url'),
        onPageFinished: (url) async {
          print('[WebView] Loaded: $url');
          // Inject auth BEFORE bridge so modules can read it immediately
          if (widget.authContext.isNotEmpty) {
            await _injectAuthContext();
          }
          await _injectBridgeInterface();
          setState(() => _pageLoaded = true);
        },
        onWebResourceError: (e) =>
            print('[WebView] Error: ${e.description}'),
      ))
      ..addJavaScriptChannel(
        'shellBridge',
        onMessageReceived: (msg) => _handleBridgeMessage(msg.message),
      );

    // Enable remote debugging on Android
    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller.loadRequest(Uri.parse(widget.url));
  }

  void _subscribeToConnectivity() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      final isOnline = result != ConnectivityResult.none;
      if (isOnline && !_wasOnline) {
        // Transitioned from offline to online — notify JS
        _dispatchOnlineEvent();
      }
      _wasOnline = isOnline;
    });
  }

  Future<void> _dispatchOnlineEvent() async {
    if (!_pageLoaded) return;
    print('[WebView] Dispatching foundry:online to ${widget.url}');
    await _controller.runJavaScript('''
      window.dispatchEvent(new CustomEvent('foundry:online'));
    ''');
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Inject the Promise-based bridge interface after page load.
  /// Pattern from POC — injects after onPageFinished to guarantee
  /// the native shellBridge channel is available before wrapping it.
  Future<void> _injectBridgeInterface() async {
    await _controller.runJavaScript('''
      (function() {
        if (window.__foundryBridgeInjected) return;
        window.__foundryBridgeInjected = true;

        let _callbackId = 0;
        const _pending = {};

        // Listen for Flutter responses
        window.addEventListener('flutterResponse', function(event) {
          const { id, result } = event.detail;
          const cb = _pending[id];
          if (cb) {
            cb.resolve(result);
            delete _pending[id];
          }
        });

        // Store native channel reference before overwriting shellBridge
        const _nativeChannel = window.shellBridge;

        // Expose clean Promise-based API
        window.shellBridge = {
          _call: function(method, args) {
            return new Promise(function(resolve, reject) {
              const id = ++_callbackId;
              _pending[id] = { resolve, reject };

              // 30s timeout guard
              setTimeout(function() {
                if (_pending[id]) {
                  delete _pending[id];
                  reject(new Error('Bridge timeout: ' + method));
                }
              }, 30000);

              _nativeChannel.postMessage(
                JSON.stringify({ id: id, method: method, args: args || {} })
              );
            });
          },

          ping:            function()   { return this._call('ping', {}); },
          capturePhoto:    function(a)  { return this._call('capturePhoto', a || {}); },
          getAuthToken:    function()   { return this._call('getAuthToken', {}); },
          getNetworkState: function()   { return this._call('getNetworkState', {}); },
          readFile:        function(a)  { return this._call('readFile', a || {}); },
          scanBarcode:     function()   { return this._call('scanBarcode', {}); },
        };

        console.log('[Foundry] Bridge interface injected');
      })();
    ''');
  }

  /// Inject auth token and config so React modules can call the API.
  /// authContext now includes apiBaseUrl (added in ModuleListScreen._startServer).
  Future<void> _injectAuthContext() async {
    final encoded = jsonEncode(widget.authContext);
    await _controller.runJavaScript('''
      window.__foundry_auth__ = $encoded;
      console.log('[Foundry] Auth context injected');
    ''');
  }

  /// Receive a message from JS, route to ShellBridge, send response back.
  Future<void> _handleBridgeMessage(String message) async {
    try {
      final Map<String, dynamic> req = jsonDecode(message);
      final int id = req['id'] as int;
      final String method = req['method'] as String;
      final Map<String, dynamic> args =
          (req['args'] as Map<String, dynamic>?) ?? {};

      final result = await _bridge.handleCall(method, args);
      await _sendResponse(id, result);
    } catch (e) {
      print('[WebView] Bridge message error: $e');
    }
  }

  /// Send bridge response back to JS via CustomEvent.
  Future<void> _sendResponse(int id, Map<String, dynamic> result) async {
    final payload = jsonEncode({'id': id, 'result': result});
    await _controller.runJavaScript('''
      window.dispatchEvent(new CustomEvent('flutterResponse', {
        detail: $payload
      }));
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_pageLoaded)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
