/// A modular, type-safe deep link orchestration library for Flutter.
///
/// This library provides a composable pipeline for receiving, validating,
/// deduplicating, and dispatching deep links in Flutter applications.
///
/// ## Core concepts
///
/// - **[DeepLinkIntent]** — the immutable value object that represents an
///   incoming deep link.
/// - **[DeepLinkOrchestrator]** — the top-level coordinator that wires
///   sources, policies, and the dispatcher together.
/// - **[DeepLinkDispatcher]** — routes resolved intents to the correct
///   [DeepLinkHandler].
/// - **[DeepLinkValidator]** — a ready-to-use [DeepLinkValidationPolicy]
///   that checks scheme, host, and path.
///
/// ## Quick start
///
/// ```dart
/// final orchestrator = DeepLinkOrchestrator(
///   sources: [AppLinksDeepLinkSource()],
///   validationPolicy: DeepLinkValidator(
///     expectedHost: 'example.com',
///     customScheme: 'myapp',
///     supportedPaths: ['/product', '/invite'],
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
library deep_link_orchestrator;

export 'src/sources/app_links_deep_link_source.dart';
export 'src/interfaces/deep_link_handler.dart';
export 'src/interfaces/deep_link_policy.dart';
export 'src/interfaces/deep_link_source.dart';
export 'src/deep_link_orchestrator.dart';
export 'src/deep_link_dispatcher.dart';
export 'src/deep_link_validator.dart';
export 'src/deep_link_logger.dart';
export 'src/deep_link_intent.dart';
