import '../deep_link_intent.dart';
import 'deep_link_policy.dart';

abstract class DeepLinkHandler {
  bool get requiresAuthentication => false;

  bool canHandle(DeepLinkIntent intent);

  Future<void> handle({
    required DeepLinkHandlerContext context,
    required DeepLinkIntent intent,
  });
}
