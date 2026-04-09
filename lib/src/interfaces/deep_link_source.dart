import '../deep_link_intent.dart';

typedef DeepLinkIntentSink = Future<void> Function(DeepLinkIntent intent);

abstract interface class DeepLinkSource {
  String get id;

  Future<void> initialize(DeepLinkIntentSink onIntent);

  Future<DeepLinkIntent?> getInitialIntent();

  Future<void> dispose();
}
