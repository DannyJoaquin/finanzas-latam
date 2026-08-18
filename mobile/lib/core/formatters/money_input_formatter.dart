import 'package:flutter/services.dart';

/// Formats monetary input with comma-separated thousands and an optional
/// decimal part, e.g. 60000 -> 60,000 and 1250.5 -> 1,250.5.
class MoneyInputFormatter extends TextInputFormatter {
  MoneyInputFormatter({this.decimalDigits = 2});

  final int decimalDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '').replaceAll(' ', '');
    if (raw.isEmpty) return newValue;
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(raw)) return oldValue;

    final parts = raw.split('.');
    var integerPart = parts.first;
    final hasDecimalSeparator = parts.length > 1;
    var decimalPart = hasDecimalSeparator ? parts[1] : '';

    integerPart = integerPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (integerPart.isEmpty) integerPart = '0';
    if (decimalPart.length > decimalDigits) {
      decimalPart = decimalPart.substring(0, decimalDigits);
    }

    final grouped = _groupThousands(integerPart);
    final formatted = grouped + (hasDecimalSeparator ? '.$decimalPart' : '');

    final rawBeforeCursor = raw.substring(
      0,
      newValue.selection.end.clamp(0, raw.length),
    );
    final digitsBeforeCursor = rawBeforeCursor
        .replaceAll(RegExp(r'\D'), '')
        .length;
    final cursorAfterDecimalPoint = rawBeforeCursor.contains('.');
    final cursor = _cursorForDigits(
      formatted,
      digitsBeforeCursor,
      includeDecimalPoint: cursorAfterDecimalPoint,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  String _groupThousands(String value) {
    final chunks = <String>[];
    for (var end = value.length; end > 0; end -= 3) {
      final start = (end - 3).clamp(0, end);
      chunks.insert(0, value.substring(start, end));
    }
    return chunks.join(',');
  }

  int _cursorForDigits(
    String value,
    int digitCount, {
    required bool includeDecimalPoint,
  }) {
    if (digitCount == 0) {
      return includeDecimalPoint && value.startsWith('0.') ? 2 : 0;
    }
    var seen = 0;
    for (var i = 0; i < value.length; i++) {
      if (RegExp(r'\d').hasMatch(value[i])) {
        seen++;
        if (seen == digitCount) {
          final afterDigit = i + 1;
          if (includeDecimalPoint &&
              afterDigit < value.length &&
              value[afterDigit] == '.') {
            return afterDigit + 1;
          }
          return afterDigit;
        }
      }
    }
    return value.length;
  }
}

/// Parses values formatted by [MoneyInputFormatter] for API payloads.
double? parseMoneyInput(String value) {
  final normalized = value.replaceAll(',', '').replaceAll(' ', '').trim();
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

String formatMoneyInputValue(num value, {int decimalDigits = 2}) {
  final fixed = value.toStringAsFixed(decimalDigits);
  final parts = fixed.split('.');
  final integer = parts.first;
  final chunks = <String>[];
  for (var end = integer.length; end > 0; end -= 3) {
    final start = (end - 3).clamp(0, end);
    chunks.insert(0, integer.substring(start, end));
  }
  if (decimalDigits == 0) return chunks.join(',');
  return '${chunks.join(',')}.${parts[1]}';
}
