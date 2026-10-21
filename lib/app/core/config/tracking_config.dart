/// Centralized configuration for GPS tracking.
///
/// Change these values here only — nothing else in the tracking code should
/// hardcode an interval.
class TrackingConfig {
  /// How often (in seconds) the foreground service flushes the locally
  /// buffered GPS points to the backend, as a batch, while a trip is active.
  ///
  /// This is the server communication cadence — it must NOT be confused
  /// with [captureIntervalSeconds], which is much finer-grained and never
  /// results in its own HTTP request.
  static const int locationUpdateIntervalSeconds = 15;

  /// How often (in seconds) GPS positions are captured into the local
  /// buffer/queue between flushes. Several samples accumulate for every
  /// one [locationUpdateIntervalSeconds] flush.
  static const int captureIntervalSeconds = 5;

  /// Maximum number of buffered points sent in a single flush POST.
  static const int maxBatchSize = 50;

  /// Hard cap on the local queue size, to bound storage growth during an
  /// extended offline period.
  static const int maxQueuedPoints = 2000;
}
