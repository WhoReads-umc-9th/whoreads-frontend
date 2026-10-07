import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/kakao_oauth_session.dart';

class KakaoLoginPage extends StatefulWidget {
  final KakaoOAuthSession session;

  const KakaoLoginPage({super.key, required this.session});

  @override
  State<KakaoLoginPage> createState() => _KakaoLoginPageState();
}

class _KakaoLoginPageState extends State<KakaoLoginPage> {
  late final WebViewController _controller;
  bool _completed = false;
  int _progress = 0;
  String? _pageError;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onProgress: (progress) {
            if (mounted && !_completed) {
              setState(() => _progress = progress);
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) _showPageError();
          },
        ),
      );
      await _controller.loadRequest(widget.session.authorizationUri);
    } catch (_) {
      _showPageError();
    }
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null || _completed || !mounted) {
      return NavigationDecision.prevent;
    }
    if (widget.session.isCallback(uri)) {
      // 브라우저가 콜백을 호출하기 전에 차단한다. 서비스가 code를 한 번만
      // 교환하여 서버의 JSON을 받아 앱의 기존 로그인/가입 흐름을 이어간다.
      if (request.isMainFrame) {
        _completed = true;
        Navigator.of(context).pop(widget.session.parseCallback(uri));
      }
      return NavigationDecision.prevent;
    }
    if (uri.scheme == 'https' || uri.toString() == 'about:blank') {
      return NavigationDecision.navigate;
    }
    if (request.isMainFrame) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('카카오계정으로 로그인해주세요.')));
    }
    return NavigationDecision.prevent;
  }

  void _showPageError() {
    if (!mounted || _completed) return;
    setState(() => _pageError = '카카오 로그인 화면을 불러올 수 없습니다.');
  }

  Future<void> _retry() async {
    setState(() {
      _pageError = null;
      _progress = 0;
    });
    try {
      await _controller.loadRequest(widget.session.authorizationUri);
    } catch (_) {
      _showPageError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('카카오 로그인')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_progress < 100 && _pageError == null)
            LinearProgressIndicator(value: _progress / 100),
          if (_pageError != null)
            ColoredBox(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_pageError!),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _retry, child: const Text('다시 시도')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
