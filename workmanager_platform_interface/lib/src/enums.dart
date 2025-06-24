/// Enum for specifying the frequency at which periodic work repeats.
enum Frequency {
  /// When no frequency is given.
  never,

  /// Work repeats with a minimal interval of 15 minutes.
  min15minutes,

  /// Work repeats with an interval of 30 minutes.
  min30minutes,

  /// Work repeats with an interval of 1 hour.
  hourly,

  /// Work repeats with an interval of 6 hours.
  sixHourly,

  /// Work repeats with an interval of 12 hours.
  twelveHourly,

  /// Work repeats with an interval of 1 day.
  daily,

  /// Work repeats with an interval of 1 week.
  weekly,
}
