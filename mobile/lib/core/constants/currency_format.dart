import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/auth/providers/auth_provider.dart';

/// Returns a [NumberFormat] for the given ISO-4217 [currency] code.
/// USD → "$ 0.00", everything else falls back to the local symbol with 0 decimals.
NumberFormat currencyFmt(String currency) {
  switch (currency) {
    case 'USD':
      return NumberFormat.currency(locale: 'en_US', symbol: '\$ ', decimalDigits: 2);
    case 'GTQ':
      return NumberFormat.currency(locale: 'en_US', symbol: 'Q ', decimalDigits: 2);
    case 'MXN':
      return NumberFormat.currency(locale: 'es_MX', symbol: '\$ ', decimalDigits: 2);
    case 'CRC':
      return NumberFormat.currency(locale: 'en_US', symbol: '₡ ', decimalDigits: 0);
    case 'NIO':
      return NumberFormat.currency(locale: 'en_US', symbol: 'C\$ ', decimalDigits: 2);
    case 'HNL':
    default:
      return NumberFormat.currency(locale: 'en_US', symbol: 'L ', decimalDigits: 0);
  }
}

/// Riverpod provider that exposes a [NumberFormat] based on the
/// currency configured in the user's profile settings.
final currencyFmtProvider = Provider<NumberFormat>((ref) {
  final currency = ref.watch(currencyProvider);
  return currencyFmt(currency);
});
