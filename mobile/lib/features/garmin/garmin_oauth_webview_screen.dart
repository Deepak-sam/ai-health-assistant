import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Displays the backend-provided Garmin consent screen in a webview and
/// pops with the redirect URI once Garmin (and then the backend, after
/// completing the server-side OAuth2 PKCE token exchange) redirects to the
/// app's registered custom scheme, e.g.
/// `familyhealth://garmin-callback?status=connected&session_ref=...`.
///
/// The app never sees a Garmin client secret or access/refresh token here —
/// only this short-lived, backend-issued session reference
/// (ARCHITECTURE.md §6).
class GarminOAuthWebViewScreen extends StatefulWidget {
  const GarminOAuthWebViewScreen({super.key, required this.authorizeUrl, required this.redirectScheme});

  final String authorizeUrl;
  final String redirectScheme;

  @override
  State<GarminOAuthWebViewScreen> createState() => _GarminOAuthWebViewScreenState();
}

class _GarminOAuthWebViewScreenState extends State<GarminOAuthWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            if (request.url.startsWith('${widget.redirectScheme}://')) {
              Navigator.of(context).pop(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizeUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Garmin'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
