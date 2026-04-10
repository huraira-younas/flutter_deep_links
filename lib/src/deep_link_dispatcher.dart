import 'interfaces/deep_link_handler.dart';
import 'interfaces/deep_link_policy.dart';
import 'deep_link_intent.dart';

/// Routes [DeepLinkIntent] instances to their registered [DeepLinkHandler].
///
/// Handlers are keyed by the **runtime type** of the intent they handle.
/// Register them with [registerHandler] or [registerHandlers] before calling
/// [DeepLinkOrchestrator.initialize].
///
/// Example:
/// ```dart
/// orchestrator.dispatcher.registerHandlers({
///   ProductIntent: ProductHandler(),
///   InviteIntent: InviteHandler(),
/// });
/// ```
class DeepLinkDispatcher {
  /// Creates a [DeepLinkDispatcher], optionally pre-populated with
  /// [handlers].
  DeepLinkDispatcher({Map<Type, DeepLinkHandler>? handlers})
    : _handlers = Map<Type, DeepLinkHandler>.from(handlers ?? const {});

  final Map<Type, DeepLinkHandler> _handlers;

  /// Replaces all currently registered handlers with [handlers].
  ///
  /// Any previously registered handlers are removed before the new map is
  /// applied.
  void registerHandlers(Map<Type, DeepLinkHandler> handlers) {
    _handlers.clear();
    _handlers.addAll(handlers);
  }

  /// Registers [handler] for the given [intentType], overwriting any
  /// previously registered handler for that type.
  void registerHandler(Type intentType, DeepLinkHandler handler) {
    _handlers[intentType] = handler;
  }

  /// Dispatches [intent] to its registered [DeepLinkHandler].
  ///
  /// Throws an [Exception] if:
  /// - No handler is registered for the intent's runtime type, or the
  ///   registered handler returns `false` from [DeepLinkHandler.canHandle].
  /// - The handler requires authentication but
  ///   [DeepLinkAuthenticationPolicy.isAuthenticated] is `false`; in this
  ///   case the URI is also saved via [DeepLinkPendingStore.savePending].
  Future<void> dispatch({
    required DeepLinkHandlerContext context,
    required DeepLinkIntent intent,
  }) async {
    final type = intent.runtimeType;
    final handler = _handlers[type];

    if (handler == null || !handler.canHandle(intent)) {
      throw Exception('No handler registered for $type');
    }

    if (handler.requiresAuthentication && !context.authPolicy.isAuthenticated) {
      await context.pendingStore.savePending(intent.uri);
      throw Exception('Authentication required for $type');
    }

    await handler.handle(context: context, intent: intent);
    await context.pendingStore.clearPending();
  }
}
