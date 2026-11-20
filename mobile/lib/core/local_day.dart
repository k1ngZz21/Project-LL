/// Calendar-day helpers based on the device's local time zone.
///
/// Timestamps are stored in UTC, but streaks, daily quests and weekly chests
/// follow the learner's local calendar day, so a lesson finished at 07:00 in
/// Manila counts toward that local day rather than the previous UTC day.
library;

/// Returns `yyyy-mm-dd` for the local calendar day containing [time].
String localDateKey(DateTime time) => dateKeyOf(time.toLocal());

/// Returns `yyyy-mm-dd` built from [date]'s own fields, with no time zone
/// conversion. Use this for values that already represent a calendar day.
String dateKeyOf(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Local midnight at the start of the day containing [time].
DateTime localDayStart(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Local midnight at the start of the day after the one containing [time].
DateTime localNextDayStart(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day + 1);
}

/// Local midnight on the Monday of the week containing [time].
DateTime localWeekStart(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day - (local.weekday - 1));
}

/// A date-only value for the local calendar day of [time], represented as
/// UTC midnight so it compares and hashes consistently.
DateTime localCalendarDate(DateTime time) {
  final local = time.toLocal();
  return DateTime.utc(local.year, local.month, local.day);
}
