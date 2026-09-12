import 'package:intl/intl.dart';

final DateFormat dateFmt = DateFormat('yyyy-MM-dd');
final DateFormat dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');
final DateFormat prettyDateFmt = DateFormat('MMM d, yyyy');
final DateFormat prettyDateTimeFmt = DateFormat('MMM d, yyyy h:mm a');
final DateFormat timeFmt = DateFormat('h:mm a');

String nowIso() => DateTime.now().toIso8601String();

/// Start of today's date (midnight).
DateTime startOfDay([DateTime? d]) {
  final x = d ?? DateTime.now();
  return DateTime(x.year, x.month, x.day);
}

DateTime startOfWeek([DateTime? d]) {
  final s = startOfDay(d);
  return s.subtract(Duration(days: s.weekday - 1));
}

DateTime startOfMonth([DateTime? d]) {
  final x = d ?? DateTime.now();
  return DateTime(x.year, x.month);
}

/// Parse ISO8601 string safely.
DateTime? tryParse(String? s) => s == null ? null : DateTime.tryParse(s);
