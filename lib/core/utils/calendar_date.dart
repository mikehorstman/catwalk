/// A local calendar day, with no time component.
///
/// Game days are calendar dates in the device timezone. Comparing these
/// instead of [DateTime] avoids rewarding or penalizing the same day twice
/// when the app is opened more than once.
class CalendarDate {
  const CalendarDate(this.year, this.month, this.day);

  factory CalendarDate.fromDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return CalendarDate(local.year, local.month, local.day);
  }

  factory CalendarDate.today() => CalendarDate.fromDateTime(DateTime.now());

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

  final int year;
  final int month;
  final int day;

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
