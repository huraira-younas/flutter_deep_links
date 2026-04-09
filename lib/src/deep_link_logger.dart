import 'dart:developer' as developer;

abstract interface class DeepLinkLogger {
  void info({required String message, required String tag});
  void warn({required String message, required String tag});
  void error({
    required String message,
    StackTrace? stackTrace,
    required String tag,
    Object? error,
  });
}

class NoopDeepLinkLogger implements DeepLinkLogger {
  const NoopDeepLinkLogger();

  @override
  void info({required String message, required String tag}) {}

  @override
  void warn({required String message, required String tag}) {}

  @override
  void error({
    required String message,
    StackTrace? stackTrace,
    required String tag,
    Object? error,
  }) {}
}

class DeveloperDeepLinkLogger implements DeepLinkLogger {
  const DeveloperDeepLinkLogger();

  @override
  void info({required String message, required String tag}) {
    developer.log(message, name: tag);
  }

  @override
  void warn({required String message, required String tag}) {
    developer.log(message, name: tag, level: 900);
  }

  @override
  void error({
    required String message,
    StackTrace? stackTrace,
    required String tag,
    Object? error,
  }) {
    developer.log(
      message,
      stackTrace: stackTrace,
      error: error,
      level: 1000,
      name: tag,
    );
  }
}
