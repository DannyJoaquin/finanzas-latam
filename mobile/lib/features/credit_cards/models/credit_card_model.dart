class CreditCardModel {
  const CreditCardModel({
    required this.id,
    required this.name,
    required this.network,
    required this.cutOffDay,
    required this.paymentDueDays,
    this.creditLimit,
    this.color,
  });

  final String id;
  final String name;
  final String network; // visa | mastercard | amex | other
  final int cutOffDay;
  final int paymentDueDays;
  final double? creditLimit;
  final String? color;

  factory CreditCardModel.fromJson(Map<String, dynamic> j) => CreditCardModel(
        id: j['id'] as String,
        name: j['name'] as String,
        network: j['network'] as String? ?? 'other',
        cutOffDay: j['cutOffDay'] as int? ?? 15,
        paymentDueDays: j['paymentDueDays'] as int? ?? 20,
        creditLimit: j['creditLimit'] != null
            ? double.parse(j['creditLimit'].toString())
            : null,
        color: j['color'] as String?,
      );
}

class CreditCardSummary {
  const CreditCardSummary({
    required this.id,
    required this.name,
    required this.network,
    required this.cutOffDay,
    required this.paymentDueDays,
    required this.currentCycleStart,
    required this.currentCycleEnd,
    required this.nextCutOffDate,
    required this.paymentDueDate,
    required this.daysUntilCutOff,
    required this.daysUntilPayment,
    required this.currentBalance,
    required this.overdueBalance,
    this.closedCyclePaymentDue,
    this.daysUntilClosedPayment,
    this.creditLimit,
    this.utilizationPct,
    this.color,
    this.limitCurrency = 'HNL',
  });

  final String id;
  final String name;
  final String network;
  final int cutOffDay;
  final int paymentDueDays;
  final String currentCycleStart;
  final String currentCycleEnd;
  final String nextCutOffDate;
  final String paymentDueDate;
  final int daysUntilCutOff;
  final int daysUntilPayment;
  final double currentBalance;
  final double overdueBalance;
  final String? closedCyclePaymentDue;
  final int? daysUntilClosedPayment;
  final double? creditLimit;
  final int? utilizationPct;
  final String? color;
  final String limitCurrency;

  factory CreditCardSummary.fromJson(Map<String, dynamic> j) => CreditCardSummary(
        id: j['id'] as String,
        name: j['name'] as String,
        network: j['network'] as String? ?? 'other',
        cutOffDay: j['cutOffDay'] as int? ?? 15,
        paymentDueDays: j['paymentDueDays'] as int? ?? 20,
        currentCycleStart: j['currentCycleStart'] as String? ?? '',
        currentCycleEnd: j['currentCycleEnd'] as String? ?? '',
        nextCutOffDate: j['nextCutOffDate'] as String? ?? '',
        paymentDueDate: j['paymentDueDate'] as String? ?? '',
        daysUntilCutOff: j['daysUntilCutOff'] as int? ?? 0,
        daysUntilPayment: j['daysUntilPayment'] as int? ?? 0,
        currentBalance: (j['currentBalance'] as num? ?? 0).toDouble(),
        overdueBalance: (j['overdueBalance'] as num? ?? 0).toDouble(),
        closedCyclePaymentDue: j['closedCyclePaymentDue'] as String?,
        daysUntilClosedPayment: j['daysUntilClosedPayment'] as int?,
        creditLimit: j['creditLimit'] != null
            ? double.parse(j['creditLimit'].toString())
            : null,
        utilizationPct: j['utilizationPct'] as int?,
        color: j['color'] as String?,
        limitCurrency: j['limitCurrency'] as String? ?? 'HNL',
      );
}
