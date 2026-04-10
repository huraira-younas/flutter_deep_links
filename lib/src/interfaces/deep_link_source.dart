import '../deep_link_intent.dart';

/// A callback invoked by a [DeepLinkSource] each time a new intent arrives.
typedef DeepLinkIntentSink = Future<void> Function(DeepLinkIntent intent);

/// Produces [DeepLinkIntent] instances from a platform-specific link channel.
///
/// Implement this interface to integrate custom deep-link providers (e.g.
/// Firebase Dynamic Links, Branch, or a custom URL scheme). Register one or
/// more sources with [DeepLinkOrchestrator] at construction time.
///
/// The lifecycle of a source is:
/// 1. [initialize] — subscribe to the platform channel and forward incoming
///    URIs to [onIntent].
/// 2. [getInitialIntent] — retrieve the link that cold-started the app, if
///    any.
/// 3. [dispose] — cancel subscriptions and release resources.
///
/// See also:
/// - [AppLinksDeepLinkSource] — a ready-made implementation backed by the
///   `app_links` package.
abstract interface class DeepLinkSource {
  /// A stable identifier for this source (e.g. `'app_links'`).
  ///
  /// The identifier is stored in [DeepLinkIntent.sourceId] so handlers and
  /// deduplication strategies can distinguish the origin of an intent.
  String get id;

  /// Subscribes to the platform channel and begins forwarding intents to
  /// [onIntent].
  ///
  /// Called once by [DeepLinkOrchestrator.initialize]. Implementations
  /// should be idempotent: calling [initialize] multiple times must not
  /// create duplicate subscriptions.
  Future<void> initialize(DeepLinkIntentSink onIntent);

  /// Returns the [DeepLinkIntent] that launched the app, or `null` if the
  /// app was opened normally.
  ///
  /// Called once by [DeepLinkOrchestrator.checkInitialIntent] after
  /// [initialize].
  Future<DeepLinkIntent?> getInitialIntent();

  /// Cancels all active subscriptions and releases platform resources.
  ///
  /// After [dispose] returns this source must not invoke [onIntent].
  Future<void> dispose();
}
