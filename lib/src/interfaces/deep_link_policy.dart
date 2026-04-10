import '../deep_link_intent.dart';

// ---------------------------------------------------------------------------
// Abstract policies
// ---------------------------------------------------------------------------

abstract interface class DeepLinkValidationPolicy {
  String? failureReason(Uri uri);
}

abstract interface class DeepLinkAuthenticationPolicy {
  bool get isAuthenticated;
}

abstract interface class DeepLinkDeduplicationStrategy {
  String fingerprintOf(DeepLinkIntent intent);
}

abstract interface class DeepLinkPendingStore {
  Future<void> savePending(Uri uri);

  Future<void> clearPending();

  Uri? readPending();
}

// ---------------------------------------------------------------------------
// Default implementations
// ---------------------------------------------------------------------------

class AllowAllDeepLinkValidationPolicy implements DeepLinkValidationPolicy {
  const AllowAllDeepLinkValidationPolicy();

  @override
  String? failureReason(Uri uri) => null;
}

class AlwaysAuthenticatedPolicy implements DeepLinkAuthenticationPolicy {
  const AlwaysAuthenticatedPolicy();

  @override
  bool get isAuthenticated => true;
}

class DefaultDeepLinkDeduplicationStrategy
    implements DeepLinkDeduplicationStrategy {
  const DefaultDeepLinkDeduplicationStrategy();

  @override
  String fingerprintOf(DeepLinkIntent intent) =>
      '${intent.sourceId}:${intent.uri}';
}

class TimeWindowDeepLinkDeduplicationStrategy
    implements DeepLinkDeduplicationStrategy {
  TimeWindowDeepLinkDeduplicationStrategy({
    this.windowDuration = const Duration(seconds: 1),
  });

  final Duration windowDuration;

  String? _lastEmittedFingerprint;
  String? _lastSemanticKey;
  DateTime? _expiresAt;

  @override
  String fingerprintOf(DeepLinkIntent intent) {
    final semanticKey = '${intent.sourceId}:${intent.uri}';
    final now = DateTime.now();

    if (_lastSemanticKey == semanticKey && now.isBefore(_expiresAt!)) {
      return _lastEmittedFingerprint!;
    }

    _lastSemanticKey = semanticKey;
    _expiresAt = now.add(windowDuration);
    return _lastEmittedFingerprint =
        '$semanticKey#${now.microsecondsSinceEpoch}';
  }
}

class NoopDeepLinkPendingStore implements DeepLinkPendingStore {
  const NoopDeepLinkPendingStore();

  @override
  Future<void> savePending(Uri uri) async {}

  @override
  Future<void> clearPending() async {}

  @override
  Uri? readPending() => null;
}

class InMemoryDeepLinkPendingStore implements DeepLinkPendingStore {
  Uri? _pending;

  @override
  Future<void> savePending(Uri uri) async => _pending = uri;

  @override
  Future<void> clearPending() async => _pending = null;

  @override
  Uri? readPending() => _pending;
}

// ---------------------------------------------------------------------------
// Handler context
// ---------------------------------------------------------------------------

class DeepLinkHandlerContext {
  const DeepLinkHandlerContext({
    required this.pendingStore,
    required this.authPolicy,
    this.sharedData = const <String, Object?>{},
  });

  final DeepLinkAuthenticationPolicy authPolicy;
  final DeepLinkPendingStore pendingStore;
  final Map<String, Object?> sharedData;
}
