class CreditCardModel {
  const CreditCardModel({
    required this.id,
    required this.name,
    required this.network,
    required this.cutOffDay,
    required this.paymentDueDays,
    this.creditLimit,
    this.color,
    this.limitCurrency = 'HNL',
  });

  final String id;
  final String name;
  final String network; // visa | mastercard | amex | other
  final int cutOffDay;
  final int paymentDueDays;
  final double? creditLimit;
  final String? color;
  final String limitCurrency;

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
        limitCurrency: j['limitCurrency'] as String? ?? 'HNL',
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
    this.currentBalanceHNL = 0,
    this.currentBalanceUSD = 0,
    this.overdueBalanceHNL = 0,
    this.overdueBalanceUSD = 0,
    this.closedCyclePaymentDue,
    this.daysUntilClosedPayment,
    this.closedCycleStart,
    this.closedCycleEnd,
    this.closedCyclePaidAmount,
    this.closedCyclePaidDate,
    this.lastPaymentAmount,
    this.lastPaymentDate,
    required this.paymentStatus,
    this.paymentCoverage,
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
  final double currentBalanceHNL;
  final double currentBalanceUSD;
  final double overdueBalanceHNL;
  final double overdueBalanceUSD;
  final String? closedCyclePaymentDue;
  final int? daysUntilClosedPayment;
  final String? closedCycleStart;
  final String? closedCycleEnd;
  final double? closedCyclePaidAmount;
  final String? closedCyclePaidDate;
  final double? lastPaymentAmount;
  final String? lastPaymentDate;
  final String paymentStatus; // 'paid' | 'partial' | 'unpaid' | 'no_debt'
  final int? paymentCoverage; // 0–100
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
        currentBalanceHNL: (j['currentBalanceHNL'] as num? ?? 0).toDouble(),
        currentBalanceUSD: (j['currentBalanceUSD'] as num? ?? 0).toDouble(),
        overdueBalanceHNL: (j['overdueBalanceHNL'] as num? ?? 0).toDouble(),
        overdueBalanceUSD: (j['overdueBalanceUSD'] as num? ?? 0).toDouble(),
        closedCyclePaymentDue: j['closedCyclePaymentDue'] as String?,
        daysUntilClosedPayment: j['daysUntilClosedPayment'] as int?,
        closedCycleStart: j['closedCycleStart'] as String?,
        closedCycleEnd: j['closedCycleEnd'] as String?,
        closedCyclePaidAmount: j['closedCyclePaidAmount'] != null
            ? double.parse(j['closedCyclePaidAmount'].toString())
            : null,
        closedCyclePaidDate: j['closedCyclePaidDate'] as String?,
        lastPaymentAmount: j['lastPaymentAmount'] != null
            ? double.parse(j['lastPaymentAmount'].toString())
            : null,
        lastPaymentDate: j['lastPaymentDate'] as String?,
        paymentStatus: j['paymentStatus'] as String? ?? 'unpaid',
        paymentCoverage: j['paymentCoverage'] as int?,
        creditLimit: j['creditLimit'] != null
            ? double.parse(j['creditLimit'].toString())
            : null,
        utilizationPct: j['utilizationPct'] as int?,
        color: j['color'] as String?,
        limitCurrency: j['limitCurrency'] as String? ?? 'HNL',
      );
}
