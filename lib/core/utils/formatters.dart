import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );

  static final NumberFormat _numberFormat = NumberFormat('#,##0.00', 'es_ES');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');

  static String currency(num? value) {
    if (value == null) return '\$0.00';
    return _currencyFormat.format(value);
  }

  static String number(num? value) {
    if (value == null) return '0.00';
    return _numberFormat.format(value);
  }

  static String date(DateTime? date) {
    if (date == null) return '-';
    return _dateFormat.format(date.toLocal());
  }

  static String time(DateTime? date) {
    if (date == null) return '-';
    return _timeFormat.format(date.toLocal());
  }

  static String dateTime(DateTime? date) {
    if (date == null) return '-';
    return _dateTimeFormat.format(date.toLocal());
  }
}
