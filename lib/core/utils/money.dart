import 'package:intl/intl.dart';

/// Philippine peso formatting (₱).
final NumberFormat _peso =
    NumberFormat.currency(locale: 'en_PH', symbol: '\u20B1', decimalDigits: 2);

String peso(num? value) => _peso.format(value ?? 0);

String pesoCompact(num? value) {
  final v = (value ?? 0).abs();
  if (v >= 1000000) {
    return '\u20B1${(value! / 1000000).toStringAsFixed(1)}M';
  }
  if (v >= 10000) return '\u20B1${(value! / 1000).toStringAsFixed(1)}K';
  return peso(value);
}

double parsePeso(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9.\-]'), '');
  return double.tryParse(cleaned) ?? 0;
}

String fmtQty(num qty) {
  if (qty == qty.roundToDouble()) return qty.toStringAsFixed(0);
  return qty.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}
