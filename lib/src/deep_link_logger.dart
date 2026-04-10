import 'dart:developer' as developer;

/// Structured logging interface for the deep link pipeline.
///
/// Implement this interface to route log output to your preferred logging
/// backend (e.g. Firebase Crashlytics, Sentry, or a custom sink).
///
/// See also:
/// - [DeveloperDeepLinkLogger] — writes to `dart:developer` (visible in
///   DevTools).
/// - [NoopDeepLinkLogger] — silently discards all log entries.
abstract interface class DeepLinkLogger {
  /// A label prepended to every log entry produced by this logger.
  String get tag;

  /// Logs an error with an optional [error] object and [stackTrace].
  void error({required String message, StackTrace? stackTrace, Object? error});

  /// Logs an informational message.
  void info({required String message});

  /// Logs a warning message.
  void warn({required String message});
}

/// A [DeepLinkLogger] that silently discards every log entry.
///
/// Use this in production builds when deep-link logging is handled by an
/// external error-reporting service that is wired up separately.
class NoopDeepLinkLogger implements DeepLinkLogger {
  /// Creates a [NoopDeepLinkLogger].
  const NoopDeepLinkLogger();

  /// Returns `'Noop_Deep_Link_Logger'`.
  @override
  String get tag => 'Noop_Deep_Link_Logger';

  /// Does nothing.
  @override
  void info({required String message}) {}

  /// Does nothing.
  @override
  void warn({required String message}) {}

  /// Does nothing.
  @override
  void error({
    required String message,
    StackTrace? stackTrace,
    Object? error,
  }) {}
}

/// A [DeepLinkLogger] that writes to `dart:developer`.
///
/// Log entries are visible in the Flutter DevTools **Logging** tab and in
/// the IDE debug console. This is the default logger used by
/// [DeepLinkOrchestrator].
///
/// Log levels:
/// - [info] — `level 0` (standard info).
/// - [warn] — `level 900`.
/// - [error] — `level 1000`.
class DeveloperDeepLinkLogger implements DeepLinkLogger {
  /// Creates a [DeveloperDeepLinkLogger].
  const DeveloperDeepLinkLogger();

  /// Returns `'Deep_Link_Logger'`.
  @override
  String get tag => 'Deep_Link_Logger';

  /// Writes [message] at info level to `dart:developer`.
  @override
  void info({required String message}) {
    developer.log(message, name: tag);
  }

  /// Writes [message] at warning level (`900`) to `dart:developer`.
  @override
  void warn({required String message}) {
    developer.log(message, name: tag, level: 900);
  }

  /// Writes [message] at error level (`1000`) to `dart:developer`, attaching
  /// [error] and [stackTrace] when provided.
  @override
  void error({required String message, StackTrace? stackTrace, Object? error}) {
    developer.log(
      message,
      stackTrace: stackTrace,
      error: error,
      level: 1000,
      name: tag,
    );
  }
}
