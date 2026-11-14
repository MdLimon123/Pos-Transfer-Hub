class AppConfig {
  const AppConfig._();

  /// Mock REST server provided with the assessment.
  static const baseUrl = 'http://108.136.142.112:90';

  /// Automatic retries (with back-off) before a transfer is reported as failed.
  static const downloadRetries = 3;
  static const uploadRetries = 2;

  /// How many transfers may run at the same time; the rest wait in the queue.
  static const maxConcurrentTransfers = 3;
}
