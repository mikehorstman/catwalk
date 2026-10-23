import '../../../core/utils/calendar_date.dart';

/// What we stored from the step sensor's last reading: the anchor for one day.
/// Saved so restarting the app does not lose the day's starting point.
class SensorStepBaseline {
  /// Creates the anchor for [date], with the sensor value [bootSteps] it started
  /// from and the highest value seen so far, [lastReading].
  const SensorStepBaseline({
    required this.date,
    required this.bootSteps,
    required this.lastReading,
  });

  /// Reads a stored anchor. Throws when a field is missing or the wrong type.
  factory SensorStepBaseline.fromJson(Map<String, dynamic> json) {
    return SensorStepBaseline(
      date: CalendarDate.parse(json['date'] as String),
      bootSteps: json['bootSteps'] as int,
      lastReading: json['lastReading'] as int,
    );
  }

  /// The day this anchor belongs to. A new day starts a new anchor.
  final CalendarDate date;

  /// The sensor's "steps since boot" value the day is anchored to. Steps walked
  /// today are the current reading minus this.
  final int bootSteps;

  /// The highest sensor value seen today, for detecting a mid-day reboot.
  final int lastReading;

  /// The saved form, read back by [SensorStepBaseline.fromJson].
  Map<String, Object> toJson() => {
    'date': date.toIsoDate(),
    'bootSteps': bootSteps,
    'lastReading': lastReading,
  };
}

/// Tracks a day's steps from a sensor that only counts steps since boot.
///
/// The first reading of a day becomes that day's anchor, so the count starts at
/// zero. A reboot makes the sensor start over, which would look like going
/// backwards; when that happens the anchor moves to the new reading.
class SensorStepResolver {
  /// Stateless; it only holds the anchoring rules.
  const SensorStepResolver();

  /// Decides the anchor to use for [today] given the current sensor [reading]
  /// and the [stored] anchor (null when none was saved). Starts a new anchor
  /// on a new day or after a reboot; otherwise keeps the old one.
  SensorStepBaseline resolve({
    required CalendarDate today,
    required int reading,
    required SensorStepBaseline? stored,
  }) {
    if (stored == null || stored.date != today) {
      return SensorStepBaseline(
        date: today,
        bootSteps: reading,
        lastReading: reading,
      );
    }

    // The sensor counts from boot, so a reading below today's high means the
    // phone restarted. Anchor again at the new reading rather than losing the
    // walk to a negative number. The high-water mark restarts too: the old one
    // belongs to the previous boot and would make every later reading look
    // like another reboot.
    final rebooted = reading < stored.lastReading;
    return SensorStepBaseline(
      date: stored.date,
      bootSteps: rebooted ? reading : stored.bootSteps,
      lastReading: rebooted || reading > stored.lastReading
          ? reading
          : stored.lastReading,
    );
  }

  /// Steps walked today, per the anchor in [baseline].
  int stepsFor(SensorStepBaseline baseline, int reading) {
    final sinceAnchor = reading - baseline.bootSteps;
    return sinceAnchor < 0 ? 0 : sinceAnchor;
  }
}
