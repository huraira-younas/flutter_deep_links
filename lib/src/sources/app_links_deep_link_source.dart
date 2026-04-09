import 'dart:async' show StreamSubscription;

import 'package:app_links/app_links.dart';

import '../interfaces/deep_link_source.dart';
import '../deep_link_intent.dart';

class AppLinksDeepLinkSource implements DeepLinkSource {
  AppLinksDeepLinkSource({AppLinks? appLinks})
      : _appLinks = appLinks ?? AppLinks();

  static const String sourceId = 'app_links';

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;

  @override
  String get id => sourceId;

  @override
  Future<void> initialize(DeepLinkIntentSink onIntent) async {
    await _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      onIntent(RawDeepLinkIntent(sourceId: id, uri: uri));
    });
  }

  @override
  Future<DeepLinkIntent?> getInitialIntent() async {
    final uri = await _appLinks.getInitialLink();
    if (uri == null) return null;
    return RawDeepLinkIntent(sourceId: id, uri: uri);
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
