import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zentri/core/formatters/money_input_formatter.dart';

void main() {
  test('groups thousands while typing', () {
    final formatter = MoneyInputFormatter();
    final result = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(
        text: '60000',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );

    expect(result.text, '60,000');
    expect(parseMoneyInput(result.text), 60000);
  });

  test('keeps decimal values after grouping', () {
    final formatter = MoneyInputFormatter();
    final result = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(
        text: '125000.50',
        selection: TextSelection.collapsed(offset: 9),
      ),
    );

    expect(result.text, '125,000.50');
    expect(parseMoneyInput(result.text), 125000.50);
  });
}
