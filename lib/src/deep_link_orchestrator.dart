import 'dart:convert' show jsonEncode;
import 'dart:async' show Timer;

import 'interfaces/deep_link_source.dart';
import 'interfaces/deep_link_policy.dart';
import 'deep_link_dispatcher.dart';
import 'deep_link_logger.dart';
import 'deep_link_intent.dart';

class DeepLinkOrchestrator {
  DeepLinkOrchestrator({
    required List<DeepLinkSource> sources,

    DeepLinkDeduplicationStrategy? deduplicationStrategy,
    DeepLinkValidationPolicy? validationPolicy,
    DeepLinkAuthenticationPolicy? authPolicy,
    DeepLinkIntentResolver? intentResolver,
    DeepLinkPendingStore? pendingStore,
    DeepLinkDispatcher? dispatcher,

    this.debounceDelay = const Duration(milliseconds: 300),
    this.sharedData = const <String, Object?>{},
    DeepLinkLogger? logger,
  }) : _deduplicationStrategy =
           deduplicationStrategy ??
           const DefaultDeepLinkDeduplicationStrategy(),
       _validationPolicy =
           validationPolicy ?? const AllowAllDeepLinkValidationPolicy(),
       _pendingStore = pendingStore ?? const NoopDeepLinkPendingStore(),
       _authPolicy = authPolicy ?? const AlwaysAuthenticatedPolicy(),
       _logger = logger ?? const DeveloperDeepLinkLogger(),
       _dispatcher = dispatcher ?? DeepLinkDispatcher(),
       _intentResolver = intentResolver,
       _sources = sources;

  final DeepLinkDeduplicationStrategy _deduplicationStrategy;
  final DeepLinkValidationPolicy _validationPolicy;
  final DeepLinkAuthenticationPolicy _authPolicy;
  final DeepLinkIntentResolver? _intentResolver;
  final DeepLinkPendingStore _pendingStore;
  final Map<String, Object?> sharedData;
  final DeepLinkDispatcher _dispatcher;
  final List<DeepLinkSource> _sources;
  final DeepLinkLogger _logger;
  final Duration debounceDelay;

  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _lastFingerprint;
  Timer? _debounceTimer;

  DeepLinkDispatcher get dispatcher => _dispatcher;

  Future<void> initialize() async {
    if (_isInitialized) return;

    for (final source in _sources) {
      await source.initialize(_onIntentReceived);
    }

    _isInitialized = true;
    _logger.info(message: 'Initialized ${_sources.length} source(s)');
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    _isProcessing = false;

    for (final source in _sources) {
      await source.dispose();
    }
  }

  Future<void> checkInitialIntent() async {
    for (final source in _sources) {
      final intent = await source.getInitialIntent();
      if (intent == null) continue;
      await _onIntentReceived(intent);
      return;
    }

    final stored = _pendingStore.readPending();
    if (stored != null) {
      await _onIntentReceived(
        RawDeepLinkIntent(sourceId: 'stored_pending', uri: stored),
      );
    }
  }

  Future<void> handleIntent(DeepLinkIntent intent) => _onIntentReceived(intent);

  void resetDeduplication() => _lastFingerprint = null;

  Future<void> _onIntentReceived(DeepLinkIntent intent) async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDelay, () async {
      final fingerprint = _deduplicationStrategy.fingerprintOf(intent);
      if (fingerprint == _lastFingerprint) return;
      _lastFingerprint = fingerprint;
      await _processIntent(intent);
    });
  }

  Future<void> _processIntent(DeepLinkIntent intent) async {
    if (_isProcessing) {
      _logger.warn(
        message: 'Skipping deep link — another link is being processed',
      );
      return;
    }

    _isProcessing = true;
    try {
      final reason = _validationPolicy.failureReason(intent.uri);
      if (reason != null) {
        _logger.warn(message: reason);
        return;
      }

      final resolved = _intentResolver?.call(intent) ?? intent;
      _logger.info(
        message: jsonEncode({
          "message": "Dispatching intent: ${intent.uri}",
          "resolved": resolved.toJson(),
        }),
      );

      await _dispatcher.dispatch(
        intent: resolved,
        context: DeepLinkHandlerContext(
          pendingStore: _pendingStore,
          authPolicy: _authPolicy,
          sharedData: sharedData,
        ),
      );
    } catch (error, stackTrace) {
      _logger.error(
        message: 'Failed to process deep link: ${intent.uri}',
        stackTrace: stackTrace,
        error: error,
      );
    } finally {
      _isProcessing = false;
    }
  }
}
