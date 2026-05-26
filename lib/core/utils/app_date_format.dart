import 'package:intl/intl.dart';

/// Centralised date/time formatter for the whole app.
///
/// Locked to French ("fr_FR") regardless of the selected UI language so dates
/// like "26 mai 2026, 06:00" appear consistently everywhere.
///
/// All methods accept either a [String] (ISO 8601) or a [DateTime] and return
/// an empty string when the input is null/empty/unparseable.
class AppDateFormat {
  AppDateFormat._();

  /// Locale used everywhere in the app for date/time rendering.
  static const String locale = 'fr_FR';

  /// "26 mai 2026"
  static String date(Object? value) {
    final dt = _resolve(value);
    if (dt == null) return '';
    return DateFormat.yMMMMd(locale).format(dt);
  }

  /// "26 mai 2026, 06:00"
  static String dateTime(Object? value) {
    final dt = _resolve(value);
    if (dt == null) return '';
    final d = DateFormat.yMMMMd(locale).format(dt);
    final t = DateFormat.Hm(locale).format(dt);
    return '$d, $t';
  }

  /// "06:00"
  static String time(Object? value) {
    final dt = _resolve(value);
    if (dt == null) return '';
    return DateFormat.Hm(locale).format(dt);
  }

  /// "26 mai"
  static String shortDate(Object? value) {
    final dt = _resolve(value);
    if (dt == null) return '';
    return DateFormat.MMMMd(locale).format(dt);
  }

  /// "mardi 26 mai 2026"
  static String fullDate(Object? value) {
    final dt = _resolve(value);
    if (dt == null) return '';
    return DateFormat.yMMMMEEEEd(locale).format(dt);
  }

  /// "26/05/2026" — used for input fields that need a numeric form.
  static String numeric(Object? value) {
    final dt = _resolve(value);
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy', locale).format(dt);
  }

  /// French abbreviated weekday names used by [scheduleDay].
  static const Map<String, String> _frDayAbbr = <String, String>{
    'sun': 'dim.',
    'mon': 'lun.',
    'tue': 'mar.',
    'wed': 'mer.',
    'thu': 'jeu.',
    'fri': 'ven.',
    'sat': 'sam.',
  };

  /// Maps an English short day key (e.g. "thu") to its French abbreviation
  /// (e.g. "jeu."). Unknown keys are returned unchanged.
  static String scheduleDay(String day) {
    final key = day.trim().toLowerCase();
    return _frDayAbbr[key] ?? day;
  }

  /// "10:00" from a "minutes since midnight" value, always in French 24h form.
  static String minutesToTime(int minFromMidnight) {
    final h = minFromMidnight ~/ 60;
    final m = minFromMidnight % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Builds a French schedule slot label like "jeu. 10:00 - 11:00".
  static String scheduleSlot({
    required String day,
    required int startMin,
    required int endMin,
  }) {
    return '${scheduleDay(day)} ${minutesToTime(startMin)} - ${minutesToTime(endMin)}';
  }

  static DateTime? _resolve(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    final parsed = DateTime.tryParse(s);
    return parsed?.toLocal();
  }
}
