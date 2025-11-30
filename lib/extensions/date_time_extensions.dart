import '../utils/date_utils.dart';

/// Extensions für DateTime
///
/// Erweitert DateTime mit nützlichen Helper-Methoden
extension DateTimeExtensions on DateTime {
  /// Formatiert zu deutschem Datum (01.01.2025)
  String get toGermanDate => AppDateUtils.formatGerman(this);

  /// Formatiert zu deutschem Datum+Zeit (01.01.2025 14:30)
  String get toGermanDateTime => AppDateUtils.formatGermanDateTime(this);

  /// Formatiert zu ISO-Datum (2025-01-01)
  String get toIsoDate => AppDateUtils.formatISO(this);

  /// Berechnet Alter
  int get age => AppDateUtils.calculateAge(this);

  /// Ist in der Vergangenheit?
  bool get isInPast => AppDateUtils.isInPast(this);

  /// Ist in der Zukunft?
  bool get isInFuture => AppDateUtils.isInFuture(this);

  /// Ist heute?
  bool get isToday => AppDateUtils.isSameDay(this, DateTime.now());

  /// Ist gestern?
  bool get isYesterday =>
      AppDateUtils.isSameDay(this, DateTime.now().subtract(const Duration(days: 1)));

  /// Ist morgen?
  bool get isTomorrow =>
      AppDateUtils.isSameDay(this, DateTime.now().add(const Duration(days: 1)));

  /// Ist diese Woche?
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  /// Ist dieser Monat?
  bool get isThisMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  /// Ist dieses Jahr?
  bool get isThisYear => year == DateTime.now().year;

  /// Erster Tag des Monats
  DateTime get firstDayOfMonth => AppDateUtils.firstDayOfMonth(this);

  /// Letzter Tag des Monats
  DateTime get lastDayOfMonth => AppDateUtils.lastDayOfMonth(this);

  /// Nur Datum (ohne Zeit)
  DateTime get dateOnly => DateTime(year, month, day);

  /// Start des Tages (00:00:00)
  DateTime get startOfDay => DateTime(year, month, day);

  /// Ende des Tages (23:59:59)
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999, 999);

  /// Fügt Tage hinzu
  DateTime addDays(int days) => add(Duration(days: days));

  /// Subtrahiert Tage
  DateTime subtractDays(int days) => subtract(Duration(days: days));

  /// Fügt Monate hinzu
  DateTime addMonths(int months) {
    int newMonth = month + months;
    int newYear = year;

    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }

    while (newMonth < 1) {
      newMonth += 12;
      newYear--;
    }

    return DateTime(newYear, newMonth, day, hour, minute, second);
  }

  /// Subtrahiert Monate
  DateTime subtractMonths(int months) => addMonths(-months);

  /// Fügt Jahre hinzu
  DateTime addYears(int years) => DateTime(
        year + years,
        month,
        day,
        hour,
        minute,
        second,
      );

  /// Subtrahiert Jahre
  DateTime subtractYears(int years) => addYears(-years);

  /// Differenz in Tagen zu einem anderen Datum
  int differenceInDays(DateTime other) {
    return difference(other).inDays;
  }

  /// Differenz in Wochen zu einem anderen Datum
  int differenceInWeeks(DateTime other) {
    return (difference(other).inDays / 7).floor();
  }

  /// Differenz in Monaten zu einem anderen Datum (ungefähr)
  int differenceInMonths(DateTime other) {
    return ((year - other.year) * 12 + (month - other.month));
  }

  /// Differenz in Jahren zu einem anderen Datum
  int differenceInYears(DateTime other) {
    return year - other.year;
  }
}
