// App-wide configuration sourced from Dart defines.
class AppConfig {
  // API base URL override: --dart-define=API_BASE_URL=http://localhost:3000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  // Tenant identifier for SaaS/private deployments.
  static const String tenantId = String.fromEnvironment(
    'TENANT_ID',
    defaultValue: 'tenant-demo',
  );
}


