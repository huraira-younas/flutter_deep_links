import 'interfaces/deep_link_handler.dart';
import 'interfaces/deep_link_policy.dart';
import 'deep_link_intent.dart';

class DeepLinkDispatcher {
  DeepLinkDispatcher({List<DeepLinkHandler>? handlers})
    : _handlers = handlers ?? <DeepLinkHandler>[];

  final List<DeepLinkHandler> _handlers;

  void registerHandlers(List<DeepLinkHandler> handlers) {
    _handlers.addAll(handlers);
  }

  void registerHandler(DeepLinkHandler handler) {
    _handlers.add(handler);
  }

  Future<bool> dispatch({
    required DeepLinkHandlerContext context,
    required DeepLinkIntent intent,
  }) async {
    for (final handler in _handlers) {
      if (!handler.canHandle(intent)) continue;

      if (handler.requiresAuthentication &&
          !context.authPolicy.isAuthenticated) {
        await context.pendingStore.savePending(intent.uri);
        return true;
      }

      await handler.handle(context: context, intent: intent);
      await context.pendingStore.clearPending();
      return true;
    }

    return false;
  }
}
