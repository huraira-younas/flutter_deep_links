import 'interfaces/deep_link_policy.dart';

class DeepLinkValidator implements DeepLinkValidationPolicy {
  const DeepLinkValidator({
    required this.expectedHost,
    required this.customScheme,
    this.supportedPaths = const <String>[],
  });

  final List<String> supportedPaths;
  final String expectedHost;
  final String customScheme;

  bool isValid(Uri uri) => failureReason(uri) == null;

  @override
  String? failureReason(Uri uri) {
    if (!_isSupportedSchemeAndHost(uri)) {
      return 'Unsupported scheme/host: ${uri.scheme}://${uri.host}';
    }
    if (!_isSupportedPath(uri.path)) {
      return 'Unsupported path: ${uri.path}';
    }
    return null;
  }

  bool _isSupportedPath(String path) {
    if (path.isEmpty || path == '/') return false;
    return supportedPaths.any(path.startsWith);
  }

  bool _isSupportedSchemeAndHost(Uri uri) {
    if (uri.scheme == customScheme) return true;
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      return uri.host == expectedHost || uri.host == 'www.$expectedHost';
    }
    return false;
  }
}
