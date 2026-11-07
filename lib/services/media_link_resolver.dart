import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'webview_media_resolver.dart';

class ResolvedMedia {
  const ResolvedMedia({required this.originalUrl, required this.url, this.mimeType, this.headers = const {}, this.fileName, this.isHls = false, this.isDash = false});
  final String originalUrl, url;
  final String? mimeType, fileName;
  final Map<String, String> headers;
  final bool isHls, isDash;
  static bool looksLikeMediaUrl(String value) => RegExp(r'\.(mp4|m4v|mov|webm|m3u8|mpd|mp3|m4a|aac|wav|ogg|opus)(?:$|[?#])', caseSensitive: false).hasMatch(value);
}

class MediaResolutionException implements Exception {
  MediaResolutionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MediaLinkResolver {
  MediaLinkResolver({Dio? dio, WebViewMediaResolver? webViewResolver})
      : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 25), followRedirects: true, maxRedirects: 10, headers: const {'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36'})),
        _webView = webViewResolver ?? WebViewMediaResolver();
  final Dio _dio;
  final WebViewMediaResolver _webView;

  Future<ResolvedMedia> resolve(String input) async {
    final uri = Uri.tryParse(input.trim());
    if (uri == null || !uri.hasAuthority || !{'http', 'https'}.contains(uri.scheme)) throw MediaResolutionException('Enter a valid HTTP or HTTPS link.');
    final direct = await _tryMedia(uri.toString());
    if (direct != null) return direct;
    var pageUrl = uri.toString();
    try {
      final response = await _dio.get<String>(pageUrl, options: Options(responseType: ResponseType.plain, headers: {'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8'}));
      pageUrl = response.realUri.toString();
      final mime = response.headers.value(Headers.contentTypeHeader) ?? '';
      if (_isMediaMime(mime)) return _build(pageUrl, pageUrl, mime);
      final found = await _parseHtml(response.data ?? '', pageUrl);
      if (found != null) return found;
    } catch (_) {
      // Browser fallback below can work when plain HTTP inspection cannot.
    }
    final browserUrl = await _webView.resolve(pageUrl);
    if (browserUrl != null) {
      final result = await _tryMedia(browserUrl, referer: pageUrl);
      if (result != null) return result;
      if (ResolvedMedia.looksLikeMediaUrl(browserUrl)) return _build(input, browserUrl, _mime(browserUrl), headers: {'Referer': pageUrl});
    }
    throw MediaResolutionException('No playable media stream was exposed. The page may require sign-in, a password, DRM, or an unsupported player.');
  }

  Future<ResolvedMedia?> _tryMedia(String url, {String? referer}) async {
    try {
      final r = await _dio.head<void>(url, options: Options(headers: {'Accept': '*/*', if (referer != null) 'Referer': referer}));
      final mime = r.headers.value(Headers.contentTypeHeader) ?? _mime(url);
      if (_isMediaMime(mime ?? '') || ResolvedMedia.looksLikeMediaUrl(r.realUri.toString())) return _build(url, r.realUri.toString(), mime, headers: {if (referer != null) 'Referer': referer});
    } catch (_) {
      if (ResolvedMedia.looksLikeMediaUrl(url)) return _build(url, url, _mime(url), headers: {if (referer != null) 'Referer': referer});
      return null;
    }
    if (ResolvedMedia.looksLikeMediaUrl(url)) return _build(url, url, _mime(url), headers: {if (referer != null) 'Referer': referer});
    return null;
  }

  Future<ResolvedMedia?> _parseHtml(String source, String pageUrl) async {
    if (source.isEmpty) return null;
    final doc = html_parser.parse(source);
    final candidates = <String>{};
    void add(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      final value = raw.trim().replaceAll('&amp;', '&');
      final parsed = Uri.tryParse(value);
      final resolved = parsed != null && parsed.hasScheme ? parsed : Uri.parse(pageUrl).resolve(value);
      if ({'http', 'https'}.contains(resolved.scheme)) candidates.add(resolved.toString());
    }
    for (final e in doc.querySelectorAll('video,audio,source')) { add(e.attributes['src']); add(e.attributes['data-src']); }
    for (final e in doc.querySelectorAll('meta')) {
      final key = (e.attributes['property'] ?? e.attributes['name'] ?? '').toLowerCase();
      if (key.contains('video') || key.contains('audio') || key.contains('contenturl')) add(e.attributes['content']);
    }
    for (final e in doc.querySelectorAll('link[rel="preload"]')) { if ({'video','audio'}.contains(e.attributes['as'])) add(e.attributes['href']); }
    final config = RegExp(r'''["'](?:contentUrl|content_url|videoUrl|video_url|file|src|hls|dash|manifest)["']\s*:\s*["']([^"']+)["']''', caseSensitive: false);
    for (final m in config.allMatches(source)) { add(m.group(1)); }
    final media = RegExp(r'''(?:https?:)?//[^\s"'<>\\]+?\.(?:mp4|m4v|mov|webm|m3u8|mpd|mp3|m4a|aac|wav|ogg|opus)(?:\?[^\s"'<>\\]*)?''', caseSensitive: false);
    for (final m in media.allMatches(source)) { var v = m.group(0)!; if (v.startsWith('//')) v = 'https:$v'; add(v); }
    final sorted = candidates.toList()..sort((a,b) => _score(b).compareTo(_score(a)));
    for (final candidate in sorted.take(12)) { final result = await _tryMedia(candidate, referer: pageUrl); if (result != null) return result; }
    return null;
  }
  int _score(String s) { final v=s.toLowerCase(); if(v.contains('.m3u8')) return 8; if(v.contains('.mpd')) return 7; if(v.contains('.mp4')) return 6; if(v.contains('.webm')) return 5; if(v.contains('poster')||v.contains('thumb')) return -5; return 1; }
  bool _isMediaMime(String m) { final v=m.toLowerCase(); return v.startsWith('video/')||v.startsWith('audio/')||v.contains('mpegurl')||v.contains('dash+xml'); }
  String? _mime(String url) { final v=url.toLowerCase(); if(v.contains('.m3u8')) return 'application/vnd.apple.mpegurl'; if(v.contains('.mpd')) return 'application/dash+xml'; if(v.contains('.mp4')||v.contains('.m4v')) return 'video/mp4'; if(v.contains('.webm')) return 'video/webm'; if(v.contains('.mp3')) return 'audio/mpeg'; return null; }
  ResolvedMedia _build(String original, String url, String? mime, {Map<String,String> headers=const {}}) {
    final path=Uri.tryParse(url)?.pathSegments; final lower=url.toLowerCase();
    return ResolvedMedia(originalUrl: original, url: url, mimeType: mime, headers: headers, fileName: path != null && path.isNotEmpty ? path.last : null, isHls: lower.contains('.m3u8') || (mime??'').contains('mpegurl'), isDash: lower.contains('.mpd') || (mime??'').contains('dash+xml'));
  }
}
