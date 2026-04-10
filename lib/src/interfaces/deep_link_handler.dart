import '../deep_link_intent.dart';
import 'deep_link_policy.dart';

/// Processes a specific type of [DeepLinkIntent].
///
/// Register implementations with [DeepLinkDispatcher.registerHandler] keyed
/// by the concrete [DeepLinkIntent] subtype they handle.
///
/// Example:
/// ```dart
/// class ProductHandler implements DeepLinkHandler {
///   @override
///   bool get requiresAuthentication => false;
///
///   @override
///   bool canHandle(DeepLinkIntent intent) => intent is ProductIntent;
///
///   @override
///   Future<void> handle({
///     required DeepLinkHandlerContext context,
///     required DeepLinkIntent intent,
///   }) async {
///     final productIntent = intent as ProductIntent;
///     // navigate to product screen…
///   }
/// }
/// ```
abstract class DeepLinkHandler {
  /// Whether this handler requires an authenticated user session.
  ///
  /// When `true`, [DeepLinkDispatcher] checks
  /// [DeepLinkAuthenticationPolicy.isAuthenticated] before calling [handle].
  /// If the user is not authenticated the URI is saved via
  /// [DeepLinkPendingStore] and an exception is thrown.
  bool get requiresAuthentication;

  /// Returns `true` if this handler is able to process [intent].
  ///
  /// Even though the dispatcher already selects handlers by runtime type,
  /// this method allows an implementation to reject edge-case intents (e.g.
  /// URIs with unsupported query parameters).
  bool canHandle(DeepLinkIntent intent);

  /// Processes [intent] using the provided [context].
  ///
  /// Throw any exception to signal failure; the orchestrator will log the
  /// error and continue processing subsequent intents.
  Future<void> handle({
    required DeepLinkHandlerContext context,
    required DeepLinkIntent intent,
  });
}
