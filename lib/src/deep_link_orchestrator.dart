import 'dart:convert' show jsonEncode;
import 'dart:async' show Timer;

import 'interfaces/deep_link_source.dart';
import 'interfaces/deep_link_policy.dart';
import 'deep_link_dispatcher.dart';
import 'deep_link_logger.dart';
import 'deep_link_intent.dart';

/// The central coordinator for the deep link pipeline.
///
/// [DeepLinkOrchestrator] wires together one or more [DeepLinkSource]s, a
/// validation policy, a deduplication strategy, an authentication policy, and
/// a [DeepLinkDispatcher] into a single, managed pipeline.
///
/// ## Lifecycle
///
/// 1. Construct the orchestrator with your sources and policies.
/// 2. Register handlers on [dispatcher].
/// 3. Call [initialize] (typically in `initState` or `main`).
/// 4. Call [checkInitialIntent] to process any cold-start deep link.
/// 5. Call [dispose] when the orchestrator is no longer needed.
///
/// ## Example
///
/// ```dart
/// final orchestrator = DeepLinkOrchestrator(
///   sources: [AppLinksDeepLinkSource()],
///   validationPolicy: DeepLinkValidator(
///     expectedHost: 'example.com',
///     customScheme: 'myapp',
///     supportedPaths: ['/product'],
///   ),
/// );
///
/// orchestrator.dispatcher.registerHandlers({
///   ProductIntent: ProductHandler(),
/// });
///
/// await orchestrator.initialize();
/// await orchestrator.checkInitialIntent();
/// ```
class DeepLinkOrchestrator {
  /// Creates a [DeepLinkOrchestrator].
  ///
  /// [sources] must contain at least one [DeepLinkSource].
  ///
  /// All policy and strategy parameters are optional; sensible defaults are
  /// used when omitted:
  /// - [validationPolicy] defaults to [AllowAllDeepLinkValidationPolicy].
  /// - [deduplicationStrategy] defaults to
  ///   [DefaultDeepLinkDeduplicationStrategy].
  /// - [authPolicy] defaults to [AlwaysAuthenticatedPolicy].
  /// - [pendingStore] defaults to [NoopDeepLinkPendingStore].
  /// - [dispatcher] defaults to an empty [DeepLinkDispatcher].
  /// - [logger] defaults to [DeveloperDeepLinkLogger].
  /// - [debounceDelay] defaults to 300 ms.
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
  final DeepLinkDispatcher _dispatcher;
  final List<DeepLinkSource> _sources;
  final DeepLinkLogger _logger;

  /// The delay applied between receiving a raw URI and processing it.
  ///
  /// Debouncing prevents duplicate intents that arrive in rapid succession
  /// (e.g. from multiple platform callbacks) from being processed more than
  /// once. Defaults to 300 milliseconds.
  final Duration debounceDelay;

  /// Arbitrary data made available to every handler via
  /// [DeepLinkHandlerContext.sharedData].
  ///
  /// Use this map to pass app-level singletons (e.g. a navigator key or a
  /// service locator) into handlers without coupling them to global state.
  final Map<String, Object?> sharedData;

  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _lastFingerprint;
  Timer? _debounceTimer;

  /// The dispatcher used to route intents to their registered handlers.
  ///
  /// Call [DeepLinkDispatcher.registerHandler] or
  /// [DeepLinkDispatcher.registerHandlers] on this object before calling
  /// [initialize].
  DeepLinkDispatcher get dispatcher => _dispatcher;

  /// Subscribes all [DeepLinkSource]s to their platform channels.
  ///
  /// This method is idempotent: subsequent calls after the first are no-ops.
  /// Must be awaited before [checkInitialIntent] or [handleIntent].
  Future<void> initialize() async {
    if (_isInitialized) return;

    for (final source in _sources) {
      await source.initialize(_onIntentReceived);
    }

    _isInitialized = true;
    _logger.info(message: 'Initialized ${_sources.length} source(s)');
  }

  /// Cancels all subscriptions and releases resources held by each source.
  ///
  /// After [dispose] returns the orchestrator must not be used again.
  Future<void> dispose() async {
    _debounceTimer?.cancel();
    _isProcessing = false;

    for (final source in _sources) {
      await source.dispose();
    }
  }

  /// Processes the deep link that cold-started the app, if any.
  ///
  /// Iterates through [sources] in order and processes the first non-null
  /// initial intent it finds. If no source returns an initial intent,
  /// falls back to any URI stored in the [DeepLinkPendingStore].
  ///
  /// Must be called after [initialize].
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

  /// Manually injects [intent] into the pipeline.
  ///
  /// Useful for testing or for forwarding intents from custom platform
  /// channels that are not modelled as a [DeepLinkSource].
  Future<void> handleIntent(DeepLinkIntent intent) => _onIntentReceived(intent);

  /// Clears the stored deduplication fingerprint.
  ///
  /// After this call the next intent will always be processed, even if it
  /// matches the most recently seen URI. Useful after manual navigation
  /// resets where re-processing the same link is intentional.
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
