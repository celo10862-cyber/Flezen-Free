import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Inspects media URLs exposed to a normal browser page; it does not bypass DRM or access controls.
class WebViewMediaResolver {
  Future<String?> resolve(String url) async {
    final done = Completer<String?>();
    HeadlessInAppWebView? view;
    var finished = false;
    void finish(String? value) { if (finished) return; finished=true; if(!done.isCompleted) done.complete(value); view?.dispose(); }
    view = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true, mediaPlaybackRequiresUserGesture: false, allowsInlineMediaPlayback: true),
      onLoadStop: (controller, _) async {
        try {
          await Future<void>.delayed(const Duration(milliseconds: 900));
          final raw = await controller.evaluateJavascript(source: '''(() => { const s=new Set(); const add=v=>{if(typeof v==='string' && /^https?:\\/\\//i.test(v)) s.add(v)}; document.querySelectorAll('video,audio,source').forEach(e=>{add(e.currentSrc);add(e.src);add(e.getAttribute('data-src'))}); document.querySelectorAll('meta').forEach(e=>{const k=(e.getAttribute('property')||e.getAttribute('name')||'').toLowerCase();if(k.includes('video')||k.includes('audio'))add(e.content)}); performance.getEntriesByType('resource').forEach(e=>{if(/\\.(mp4|m4v|webm|m3u8|mpd|mp3|m4a|aac)(?:[?#]|$)/i.test(e.name))add(e.name)}); return JSON.stringify([...s]); })()''');
          final value=raw is String ? jsonDecode(raw) : raw;
          if(value is List && value.whereType<String>().isNotEmpty) { final list=value.whereType<String>().toList()..sort((a,b)=>_score(b).compareTo(_score(a))); finish(list.first); } else { finish(null); }
        } catch (_) { finish(null); }
      },
      onReceivedError: (controller, request, error) { if(request.isForMainFrame==true) finish(null); },
    );
    try { await view!.run(); return await done.future.timeout(const Duration(seconds:24), onTimeout:(){finish(null);return null;}); }
    catch (_) { finish(null); return null; }
  }
  int _score(String s) { final v=s.toLowerCase(); if(v.contains('.m3u8'))return 5;if(v.contains('.mpd'))return 4;if(v.contains('.mp4'))return 3;if(v.contains('.webm'))return 2;return 1; }
}
