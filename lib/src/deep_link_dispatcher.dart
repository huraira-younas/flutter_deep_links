import 'interfaces/deep_link_handler.dart';
import 'interfaces/deep_link_policy.dart';
import 'deep_link_intent.dart';

class DeepLinkDispatcher {
  DeepLinkDispatcher({Map<Type, DeepLinkHandler>? handlers})
    : _handlers = Map<Type, DeepLinkHandler>.from(handlers ?? const {});

  final Map<Type, DeepLinkHandler> _handlers;

  void registerHandlers(Map<Type, DeepLinkHandler> handlers) {
    _handlers.clear();
    _handlers.addAll(handlers);
  }

  void registerHandler(Type intentType, DeepLinkHandler handler) {
    _handlers[intentType] = handler;
  }

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
