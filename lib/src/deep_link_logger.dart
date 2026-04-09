import 'dart:developer' as developer;

abstract interface class DeepLinkLogger {
  String get tag;

  void error({required String message, StackTrace? stackTrace, Object? error});
  void info({required String message});
  void warn({required String message});
}

class NoopDeepLinkLogger implements DeepLinkLogger {
  @override
  String get tag => 'Noop_Deep_Link_Logger';

  const NoopDeepLinkLogger();

  @override
  void info({required String message}) {}

  @override
  void warn({required String message}) {}

  @override
  void error({
    required String message,
    StackTrace? stackTrace,
    Object? error,
  }) {}
}

class DeveloperDeepLinkLogger implements DeepLinkLogger {
  const DeveloperDeepLinkLogger();
  
  @override
  String get tag => 'Deep_Link_Logger';

  @override
  void info({required String message}) {
    developer.log(message, name: tag);
  }

  @override
  void warn({required String message}) {
    developer.log(message, name: tag, level: 900);
  }

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
