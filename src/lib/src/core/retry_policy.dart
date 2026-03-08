/// Retry configuration for handling transient failures.
///
/// Example:
/// ```dart
/// RetryPolicy(maxAttempts: 3)  // Basic retry
/// RetryPolicy.exponential(maxAttempts: 5)  // Exponential backoff
/// ```
class RetryPolicy {
  /// Creates a retry policy with the given configuration.
  const RetryPolicy({
    this.maxAttempts = 3,
    this.delay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.retryIf,
  });

  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Initial delay between retries.
  final Duration delay;

  /// Maximum delay cap for exponential backoff.
  final Duration maxDelay;

  /// Optional conditional retry. If provided, only retry if this returns true.
  final bool Function(Exception)? retryIf;

  /// Helper constructor for exponential backoff retry policy.
  const RetryPolicy.exponential({
    this.maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
  })  : delay = initialDelay,
        maxDelay = const Duration(seconds: 30),
        retryIf = null;
}
