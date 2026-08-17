import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/formatters/money_input_formatter.dart';

// ──────────────────────────────────────────────────────────────────────────────
//  Domain models
// ──────────────────────────────────────────────────────────────────────────────

class _AmortRow {
  final int number;
  final DateTime date;
  final double payment;
  final double capital;
  final double interest;
  final double balance;

  const _AmortRow({
    required this.number,
    required this.date,
    required this.payment,
    required this.capital,
    required this.interest,
    required this.balance,
  });
}

class _LoanResult {
  final double monthlyPayment;
  final double principal;
  final double totalPayment;
  final double totalInterest;
  final List<_AmortRow> rows;

  const _LoanResult({
    required this.monthlyPayment,
    required this.principal,
    required this.totalPayment,
    required this.totalInterest,
    required this.rows,
  });

  double get interestPct =>
      totalPayment > 0 ? (totalInterest / totalPayment * 100) : 0;
  double get capitalPct => 100 - interestPct;
}

// ──────────────────────────────────────────────────────────────────────────────
//  Screen
// ──────────────────────────────────────────────────────────────────────────────

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _termCtrl = TextEditingController();

  bool _termInMonths = true;
  _LoanResult? _result;
  bool _showTable = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _termCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final amount = parseMoneyInput(_amountCtrl.text)!;
    final annualRate = double.parse(_rateCtrl.text.replaceAll(',', '.'));
    final termInput = int.parse(_termCtrl.text.trim());
    final n = _termInMonths ? termInput : termInput * 12;
    final r = annualRate / 100 / 12;

    // French (fixed-payment) amortization formula
    double monthly;
    if (r < 1e-9) {
      monthly = amount / n;
    } else {
      final factor = math.pow(1 + r, n).toDouble();
      monthly = amount * r * factor / (factor - 1);
    }

    final total = monthly * n;
    final rows = <_AmortRow>[];
    double balance = amount;
    final now = DateTime.now();

    for (int i = 1; i <= n; i++) {
      final interest = balance * r;
      final capital = monthly - interest;
      balance -= capital;
      if (balance < 0.005) balance = 0;
      rows.add(_AmortRow(
        number: i,
        date: DateTime(now.year, now.month + i, 1),
        payment: monthly,
        capital: capital,
        interest: interest,
        balance: balance,
      ));
    }

    setState(() {
      _showTable = false;
      _result = _LoanResult(
        monthlyPayment: monthly,
        principal: amount,
        totalPayment: total,
        totalInterest: total - amount,
        rows: rows,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: isMobile
            ? IconButton(
                tooltip: 'Volver a configuración',
                onPressed: () => context.go(AppRoutes.settings),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calculadora de Préstamos',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'Simulador de crédito · Sistema Francés',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _InputCard(
                amountCtrl: _amountCtrl,
                rateCtrl: _rateCtrl,
                termCtrl: _termCtrl,
                termInMonths: _termInMonths,
                onTermChanged: (v) => setState(() => _termInMonths = v),
                onCalculate: _calculate,
              ),
              if (_result != null) ...[
                const SizedBox(height: 16),
                _ResultCard(result: _result!),
                const SizedBox(height: 16),
                _AmortizationCard(
                  result: _result!,
                  showTable: _showTable,
                  onToggle: () => setState(() => _showTable = !_showTable),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
// ──────────────────────────────────────────────────────────────────────────────
//  Input Card
// ──────────────────────────────────────────────────────────────────────────────

class _InputCard extends StatelessWidget {
  final TextEditingController amountCtrl;
  final TextEditingController rateCtrl;
  final TextEditingController termCtrl;
  final bool termInMonths;
  final ValueChanged<bool> onTermChanged;
  final VoidCallback onCalculate;

  const _InputCard({
    required this.amountCtrl,
    required this.rateCtrl,
    required this.termCtrl,
    required this.termInMonths,
    required this.onTermChanged,
    required this.onCalculate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inputFill = cs.surfaceContainerHighest.withAlpha(80);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    final inputFocusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cs.primary, width: 2),
    );
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(14),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.account_balance_outlined,
                    color: cs.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Datos del préstamo',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Completa los campos para calcular',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Monto
          TextFormField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [MoneyInputFormatter()],
            decoration: InputDecoration(
              labelText: 'Monto del préstamo',
              hintText: '100,000',
              prefixIcon:
                  const Icon(Icons.account_balance_wallet_outlined, size: 20),
              suffixText: 'L',
              filled: true,
              fillColor: inputFill,
              border: inputBorder,
              enabledBorder: inputBorder,
              focusedBorder: inputFocusBorder,
              errorBorder: inputBorder.copyWith(
                  borderSide: const BorderSide(color: Colors.red, width: 1)),
              focusedErrorBorder: inputFocusBorder.copyWith(
                  borderSide: const BorderSide(color: Colors.red, width: 2)),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa el monto';
              final val = double.tryParse(v.replaceAll(',', ''));
              if (val == null || val <= 0) return 'Monto inválido';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Tasa anual
          TextFormField(
            controller: rateCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Tasa de interés anual',
              hintText: '18.5',
              prefixIcon: const Icon(Icons.percent_outlined, size: 20),
              suffixText: '%',
              filled: true,
              fillColor: inputFill,
              border: inputBorder,
              enabledBorder: inputBorder,
              focusedBorder: inputFocusBorder,
              errorBorder: inputBorder.copyWith(
                  borderSide: const BorderSide(color: Colors.red, width: 1)),
              focusedErrorBorder: inputFocusBorder.copyWith(
                  borderSide: const BorderSide(color: Colors.red, width: 2)),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa la tasa';
              final val = double.tryParse(v.replaceAll(',', '.'));
              if (val == null || val < 0) return 'Tasa inválida';
              if (val > 300) return 'Tasa demasiado alta';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Plazo + toggle meses/años
          LayoutBuilder(
            builder: (context, constraints) {
              final termField = TextFormField(
                controller: termCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Plazo',
                  hintText: termInMonths ? '36' : '3',
                  prefixIcon:
                      const Icon(Icons.calendar_today_outlined, size: 20),
                  filled: true,
                  fillColor: inputFill,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: inputFocusBorder,
                  errorBorder: inputBorder.copyWith(
                      borderSide:
                          const BorderSide(color: Colors.red, width: 1)),
                  focusedErrorBorder: inputFocusBorder.copyWith(
                      borderSide:
                          const BorderSide(color: Colors.red, width: 2)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa el plazo';
                  final val = int.tryParse(v);
                  if (val == null || val <= 0) return 'Plazo inválido';
                  final months = termInMonths ? val : val * 12;
                  if (months > 600) return 'Máx. 50 años';
                  return null;
                },
              );
              final termSelector = Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Meses')),
                    ButtonSegment(value: false, label: Text('Años')),
                  ],
                  selected: {termInMonths},
                  onSelectionChanged: (s) => onTermChanged(s.first),
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              );

              if (constraints.maxWidth < 430) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    termField,
                    Align(
                      alignment: Alignment.centerLeft,
                      child: termSelector,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: termField),
                  const SizedBox(width: 12),
                  termSelector,
                ],
              );
            },
          ),
          // Calcular button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onCalculate,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text(
                'Calcular cuota',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ──────────────────────────────────────────────────────────────────────────────
//  Result Card
// ──────────────────────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final _LoanResult result;
  const _ResultCard({required this.result});

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00', 'es');
    final fmtShort = NumberFormat('#,##0', 'es');
    final n = result.rows.length;
    final lastDate =
        _cap(DateFormat('MMMM yyyy', 'es').format(result.rows.last.date));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: cs.primaryContainer.withAlpha(60),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.check_circle_outline,
                      color: cs.onPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Resultado',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Hero: cuota mensual ──────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary,
                    Color.lerp(cs.primary, Colors.black, 0.15)!
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Cuota mensual',
                    style: TextStyle(
                        color: cs.onPrimary.withAlpha(200), fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'L. ${fmt.format(result.monthlyPayment)}',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'durante $n ${n == 1 ? 'mes' : 'meses'}',
                    style: TextStyle(
                        color: cs.onPrimary.withAlpha(170), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Metrics 2×2 ─────────────────────────────
            Row(
              children: [
                _Metric(
                  label: 'Total a pagar',
                  value: 'L. ${fmtShort.format(result.totalPayment)}',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(width: 8),
                _Metric(
                  label: 'Total intereses',
                  value: 'L. ${fmtShort.format(result.totalInterest)}',
                  icon: Icons.trending_up_outlined,
                  accent: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Metric(
                  label: '% del total',
                  value: '${result.interestPct.toStringAsFixed(1)}% interés',
                  icon: Icons.pie_chart_outline,
                  accent: Colors.orange,
                ),
                const SizedBox(width: 8),
                _Metric(
                  label: 'Último pago',
                  value: lastDate,
                  icon: Icons.event_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Barra capital vs interés ─────────────────
            Text(
              'Distribución del pago total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Flexible(
                    flex: result.capitalPct.round().clamp(1, 99),
                    child: Container(height: 14, color: cs.primary),
                  ),
                  Flexible(
                    flex: result.interestPct.round().clamp(1, 99),
                    child: Container(height: 14, color: Colors.orange),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Legend(
                  color: cs.primary,
                  label: 'Capital ${result.capitalPct.toStringAsFixed(1)}%',
                ),
                const SizedBox(width: 16),
                _Legend(
                  color: Colors.orange,
                  label: 'Interés ${result.interestPct.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
//  Amortization Card
// ──────────────────────────────────────────────────────────────────────────────

class _AmortizationCard extends StatelessWidget {
  final _LoanResult result;
  final bool showTable;
  final VoidCallback onToggle;

  const _AmortizationCard({
    required this.result,
    required this.showTable,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tableWidth = math.max(MediaQuery.sizeOf(context).width - 32, 720.0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.table_chart_outlined,
                      color: cs.secondary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tabla de amortización',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${result.rows.length} cuotas · Sistema Francés',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onToggle,
                  child: Text(showTable ? 'Ocultar' : 'Ver tabla'),
                ),
              ],
            ),
          ),

          if (showTable) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(52),
                    1: FixedColumnWidth(108),
                    2: FixedColumnWidth(140),
                    3: FixedColumnWidth(140),
                    4: FixedColumnWidth(140),
                    5: FixedColumnWidth(140),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: cs.outlineVariant.withAlpha(32),
                    ),
                  ),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withAlpha(90),
                      ),
                      children: const [
                        _TableCellText('#', header: true),
                        _TableCellText('Fecha', header: true),
                        _TableCellText('Cuota', header: true, right: true),
                        _TableCellText('Capital', header: true, right: true),
                        _TableCellText('Interés', header: true, right: true),
                        _TableCellText('Saldo', header: true, right: true),
                      ],
                    ),
                    ...result.rows.map(
                      (row) => TableRow(
                        decoration: BoxDecoration(
                          color: row.number.isEven
                              ? cs.surfaceContainerHighest.withAlpha(45)
                              : Colors.transparent,
                        ),
                        children: [
                          _TableCellText('${row.number}'),
                          _TableCellText(
                            DateFormat('d MMM yy', 'es').format(row.date),
                          ),
                          _TableCellText(
                            NumberFormat('#,##0', 'es').format(row.payment),
                            right: true,
                          ),
                          _TableCellText(
                            NumberFormat('#,##0', 'es').format(row.capital),
                            right: true,
                            color: cs.primary,
                            emphasis: true,
                          ),
                          _TableCellText(
                            NumberFormat('#,##0', 'es').format(row.interest),
                            right: true,
                            color: Colors.orange,
                          ),
                          _TableCellText(
                            NumberFormat('#,##0', 'es').format(row.balance),
                            right: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TableCellText extends StatelessWidget {
  final String text;
  final bool header;
  final bool right;
  final Color? color;
  final bool emphasis;

  const _TableCellText(
    this.text, {
    this.header = false,
    this.right = false,
    this.color,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = color ??
        (header
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        header ? 10 : 8,
        8,
        header ? 10 : 8,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: theme.textTheme.bodySmall?.copyWith(
          color: textColor,
          fontSize: header ? 11 : 12,
          fontWeight: header || emphasis ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
//  Small helper widgets
// ──────────────────────────────────────────────────────────────────────────────

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = accent ?? cs.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withAlpha(70),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}
