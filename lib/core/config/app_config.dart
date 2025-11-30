enum AppEnvironment {
  development,
  staging,
  production,
}

class AppConfig {
  final AppEnvironment environment;
  final String appTitle;
  final bool enableLogging;

  // Singleton instance
  static AppConfig? _instance;

  factory AppConfig({
    required AppEnvironment environment,
    required String appTitle,
    bool enableLogging = false,
  }) {
    _instance ??= AppConfig._internal(
      environment: environment,
      appTitle: appTitle,
      enableLogging: enableLogging,
    );
    return _instance!;
  }

  AppConfig._internal({
    required this.environment,
    required this.appTitle,
    required this.enableLogging,
  });

  static AppConfig get instance {
    if (_instance == null) {
      throw Exception('AppConfig not initialized. Call AppConfig() first.');
    }
    return _instance!;
  }
}
