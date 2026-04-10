import 'interfaces/deep_link_policy.dart';

/// A [DeepLinkValidationPolicy] that validates URIs by scheme, host, and
/// path prefix.
///
/// Accepts a URI if:
/// 1. Its scheme matches [customScheme], **or**
/// 2. Its scheme is `https` or `http` and its host matches [expectedHost]
///    (with or without a `www.` prefix).
///
/// Additionally, when [supportedPaths] is non-empty, the URI path must start
/// with at least one of the listed prefixes.
///
/// Example:
/// ```dart
/// final validator = DeepLinkValidator(
///   expectedHost: 'example.com',
///   customScheme: 'myapp',
///   supportedPaths: ['/product', '/invite'],
/// );
///
/// final orchestrator = DeepLinkOrchestrator(
///   sources: [AppLinksDeepLinkSource()],
///   validationPolicy: validator,
/// );
/// ```
class DeepLinkValidator implements DeepLinkValidationPolicy {
  /// Creates a [DeepLinkValidator].
  ///
  /// [expectedHost] is the domain name used for universal/app links
  /// (e.g. `'example.com'`).
  ///
  /// [customScheme] is the app-specific URI scheme
  /// (e.g. `'myapp'`).
  ///
  /// [supportedPaths] is the list of path prefixes that are considered valid.
  /// An empty list disables path validation and all paths are accepted.
  const DeepLinkValidator({
    required this.expectedHost,
    required this.customScheme,
    this.supportedPaths = const <String>[],
  });

  /// The list of path prefixes that are accepted (e.g. `['/product', '/invite']`).
  ///
  /// When empty every non-root path is accepted.
  final List<String> supportedPaths;

  /// The expected host for `https`/`http` universal links
  /// (e.g. `'example.com'`).
  final String expectedHost;

  /// The custom URI scheme for app-specific deep links (e.g. `'myapp'`).
  final String customScheme;

  /// Returns `true` if [uri] passes all validation rules.
  bool isValid(Uri uri) => failureReason(uri) == null;

  /// Returns a failure description if [uri] is invalid, or `null` if valid.
  ///
  /// Validation fails when:
  /// - The scheme and host do not match [customScheme] or [expectedHost].
  /// - [supportedPaths] is non-empty and the path does not start with any
  ///   of the listed prefixes.
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
