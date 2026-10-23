/// A local calendar day, with no time component.
///
/// Game days are calendar dates in the device timezone. Comparing these
/// instead of [DateTime] avoids rewarding or penalizing the same day twice
/// when the app is opened more than once.
class CalendarDate {
  /// Builds a date from [year], [month] (1-12) and [day] (1-31).
  const CalendarDate(this.year, this.month, this.day);

  /// Takes the local calendar day of [dateTime] and drops the time.
  factory CalendarDate.fromDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return CalendarDate(local.year, local.month, local.day);
  }

  /// Today in the device timezone.
  factory CalendarDate.today() => CalendarDate.fromDateTime(DateTime.now());

  /// Reads "yyyy-MM-dd" (as written by [toIsoDate]). Throws a [FormatException]
  /// when [value] has the wrong shape.
  factory CalendarDate.parse(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      throw FormatException('Expected yyyy-MM-dd, got $value');
    }
    return CalendarDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Four-digit year.
  final int year;

  /// Month, 1 to 12.
  final int month;

  /// Day of the month, 1 to 31.
  final int day;

  /// Midnight at the start of this day, local time.
  DateTime toDateTime() => DateTime(year, month, day);

  /// Calendar arithmetic, not clock arithmetic: adding 24-hour blocks lands on
  /// the wrong date across the days the clocks change.
  CalendarDate addDays(int days) {
    return CalendarDate.fromDateTime(DateTime(year, month, day + days));
  }

  /// Whole calendar days from this date to [other], the same whether or not the
  /// clocks change in between.
  int daysUntil(CalendarDate other) {
    return DateTime.utc(
      other.year,
      other.month,
      other.day,
    ).difference(DateTime.utc(year, month, day)).inDays;
  }

  /// Text form "yyyy-MM-dd", used for storage keys and saved data.
  String toIsoDate() {
    final monthText = month.toString().padLeft(2, '0');
    final dayText = day.toString().padLeft(2, '0');
    return '$year-$monthText-$dayText';
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarDate &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIsoDate();
}
