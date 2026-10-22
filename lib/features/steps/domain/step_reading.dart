/// Where a step count came from.
///
/// Catwalk never counts steps itself. Every reading is attributed to the
/// source that produced it so the UI can be honest about what it is showing.
enum StepSource {
  /// Apple Health, on iOS, or Health Connect, on Android.
  health,

  /// The phone's built-in step sensor, through the pedometer plugin.
  sensor,

  /// Development-only mock steps. Never chosen in a release build.
  mock,
}

/// What the phone says about a day's steps.
///
/// [steps] is null when there is no reading. That is not the same as zero:
/// zero means the phone counted nothing, null means nobody could be asked.
class StepReading {
  const StepReading({required this.source, required this.steps});

  /// No source could be read.
  const StepReading.unavailable() : source = null, steps = null;

  const StepReading.health(int steps)
    : this(source: StepSource.health, steps: steps);

  const StepReading.sensor(int steps)
    : this(source: StepSource.sensor, steps: steps);

  const StepReading.mock(int steps)
    : this(source: StepSource.mock, steps: steps);

  final StepSource? source;

  final int? steps;

  /// True when the phone actually gave a number.
  bool get hasSteps => steps != null;

  @override
  String toString() => 'StepReading(${source?.name}, $steps)';
}
