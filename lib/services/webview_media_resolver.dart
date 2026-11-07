import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Inspects media URLs exposed to a normal browser page.
///
/// This does not bypass DRM, authentication, or other access controls.
class WebViewMediaResolver {
  Future<String?> resolve(String url) async {
    final done = Completer<String?>();
    HeadlessInAppWebView? view;
    var finished = false;

    void finish(String? value) {
      if (finished) return;
      finished = true;
      if (!done.isCompleted) {
        done.complete(value);
      }
      view?.dispose();
    }

    view = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
      ),
      onLoadStop: (controller, _) async {
        try {
          await Future<void>.delayed(const Duration(milliseconds: 900));

          final raw = await controller.evaluateJavascript(
            source: r'''(() => {
              const urls = new Set();

              const add = (value) => {
                if (typeof value === 'string' && /^https?:\/\//i.test(value)) {
                  urls.add(value);
                }
              };

              document.querySelectorAll('video, audio, source').forEach((element) => {
                add(element.currentSrc);
                add(element.src);
                add(element.getAttribute('data-src'));
              });

              document.querySelectorAll('meta').forEach((element) => {
                const key = (
                  element.getAttribute('property') ||
                  element.getAttribute('name') ||
                  ''
                ).toLowerCase();

                if (key.includes('video') || key.includes('audio')) {
                  add(element.content);
                }
              });

              performance.getEntriesByType('resource').forEach((entry) => {
                if (/\.(mp4|m4v|webm|m3u8|mpd|mp3|m4a|aac)(?:[?#]|$)/i.test(entry.name)) {
                  add(entry.name);
                }
              });

              return JSON.stringify([...urls]);
            })()''',
          );

          final value = raw is String ? jsonDecode(raw) : raw;

          if (value is List) {
            final candidates = value.whereType<String>().toList()
              ..sort((a, b) => _score(b).compareTo(_score(a)));

            finish(candidates.isEmpty ? null : candidates.first);
          } else {
            finish(null);
          }
        } catch (_) {
          finish(null);
        }
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame == true) {
          finish(null);
        }
      },
    );

    try {
      await view.run();
      return await done.future.timeout(
        const Duration(seconds: 24),
        onTimeout: () {
          finish(null);
          return null;
        },
      );
    } catch (_) {
      finish(null);
      return null;
    }
  }

  int _score(String url) {
    final value = url.toLowerCase();
    if (value.contains('.m3u8')) return 5;
    if (value.contains('.mpd')) return 4;
    if (value.contains('.mp4')) return 3;
    if (value.contains('.webm')) return 2;
    return 1;
  }
}
