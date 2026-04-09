typedef DeepLinkIntentResolver = DeepLinkIntent Function(DeepLinkIntent intent);

abstract class DeepLinkIntent {
  const DeepLinkIntent({
    this.attributes = const <String, Object?>{},
    this.isDeferred = false,
    required this.sourceId,
    required this.uri,
  });

  final Map<String, Object?> attributes;
  final bool isDeferred;
  final String sourceId;
  final Uri uri;

  Map<String, Object?> toJson() => {
    'uri': uri.toString(),
    'sourceId': sourceId,
    'attributes': attributes,
    'isDeferred': isDeferred,
  };
}

class RawDeepLinkIntent extends DeepLinkIntent {
  const RawDeepLinkIntent({
    required super.sourceId,
    required super.uri,
    super.attributes,
    super.isDeferred,
  });

  @override
  Map<String, Object?> toJson() => {
    'sourceId': sourceId,
    'uri': uri.toString(),
    'attributes': attributes,
    'isDeferred': isDeferred,
  };
}
