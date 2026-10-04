import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _fixedDrivers = [];
  Map<String, List<Map<String, dynamic>>> _txByDriver = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final drivers =
          await supabase.from('drivers').select().eq('contract_type', 'fixed');
      final tx = await supabase
          .from('driver_salary_transactions')
          .select()
          .order('created_at', ascending: false);

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final t in tx) {
        final id = t['driver_id'].toString();
        grouped.putIfAbsent(id, () => []).add(t);
      }

      setState(() {
        _fixedDrivers = List<Map<String, dynamic>>.from(drivers);
        _txByDriver = grouped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editSalary(Map<String, dynamic> driver) async {
    final controller =
        TextEditingController(text: (driver['monthly_salary'] ?? 0).toString());
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('الراتب الأساسي - ${driver['name']}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المبلغ الشهري (ر.س)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await supabase
        .from('drivers')
        .update({'monthly_salary': result}).eq('id', driver['id']);
    _fetch();
  }

  void _openLedger(Map<String, dynamic> driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DriverLedgerSheet(
        driver: driver,
        transactions: _txByDriver[driver['id'].toString()] ?? [],
        onChanged: _fetch,
      ),
    );
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final headerColor = PdfColor.fromInt(0xFF086591);
    final altRowColor = PdfColor.fromInt(0xFFF3F6F9);

    pw.Widget dataTable(List<String> headers, List<List<String>> rows) {
      return pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle:
            pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
        headerDecoration: pw.BoxDecoration(color: headerColor),
        cellStyle: pw.TextStyle(font: font, fontSize: 10),
        cellAlignment: pw.Alignment.centerRight,
        headerAlignment: pw.Alignment.centerRight,
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        oddRowDecoration: pw.BoxDecoration(color: altRowColor),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('كشف رواتب السائقين',
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 18, color: headerColor)),
                  pw.Text(DateTime.now().toString().substring(0, 10),
                      style: pw.TextStyle(
                          font: font, fontSize: 11, color: PdfColors.grey700)),
                ],
              ),
              pw.Divider(color: headerColor, thickness: 1.2),
            ],
          ),
        ),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: _fixedDrivers.map((driver) {
                final driverId = driver['id'].toString();
                final tx = _txByDriver[driverId] ?? [];
                final salary =
                    (driver['monthly_salary'] as num?)?.toDouble() ?? 0;
                double totalPaid = 0,
                    totalWithdrawn = 0,
                    totalBonus = 0,
                    totalOvertime = 0,
                    totalDeduction = 0;
                for (final t in tx) {
                  final amt = (t['amount'] as num?)?.toDouble() ?? 0;
                  switch (t['type']) {
                    case 'payment':
                      totalPaid += amt;
                      break;
                    case 'withdrawal':
                      totalWithdrawn += amt;
                      break;
                    case 'bonus':
                      totalBonus += amt;
                      break;
                    case 'overtime':
                      totalOvertime += amt;
                      break;
                    case 'deduction':
                      totalDeduction += amt;
                      break;
                  }
                }
                final netBalance = salary +
                    totalBonus +
                    totalOvertime -
                    totalPaid -
                    totalWithdrawn -
                    totalDeduction;

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 20),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        color: PdfColor.fromInt(0xFFE6F2F8),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                                '${driver['name']}  -  راتب أساسي: ${salary.toStringAsFixed(0)} ر.س',
                                style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 13,
                                    color: headerColor)),
                            pw.Text(
                                'الرصيد المستحق: ${netBalance.toStringAsFixed(0)} ر.س',
                                style:
                                    pw.TextStyle(font: fontBold, fontSize: 12)),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      if (tx.isEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6),
                          child: pw.Text('لا توجد حركات مسجلة',
                              style: pw.TextStyle(
                                  font: font,
                                  fontSize: 10,
                                  color: PdfColors.grey600)),
                        )
                      else
                        dataTable(
                          ['التاريخ', 'النوع', 'المبلغ', 'المدة/ملاحظة'],
                          tx.map((t) {
                            final label = switch (t['type']) {
                              'payment' => 'دفعة راتب',
                              'withdrawal' => 'سحب مقدم',
                              'bonus' => 'مكافأة',
                              'overtime' => 'أوفر تايم',
                              'deduction' => 'خصم',
                              _ => 'حركة',
                            };
                            return [
                              t['transaction_date']?.toString() ?? '',
                              label,
                              '${(t['amount'] as num).toStringAsFixed(0)} ر.س',
                              (t['period_label']?.toString().isNotEmpty ??
                                      false)
                                  ? t['period_label'].toString()
                                  : (t['note']?.toString() ?? ''),
                            ];
                          }).toList(),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        footer: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text(
                'تطبيق ميزان - صفحة ${context.pageNumber} من ${context.pagesCount}',
                style: pw.TextStyle(
                    font: font, fontSize: 9, color: PdfColors.grey600)),
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'كشف_رواتب_السائقين.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('رواتب السائقين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primary),
            tooltip: 'تصدير PDF',
            onPressed: _isLoading ? null : _exportPdf,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fixedDrivers.isEmpty
              ? const Center(
                  child: Text('لا يوجد سائقين براتب ثابت حالياً',
                      style: TextStyle(color: AppTheme.textMuted)))
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _fixedDrivers.length,
                    itemBuilder: (context, index) {
                      final driver = _fixedDrivers[index];
                      final driverId = driver['id'].toString();
                      final tx = _txByDriver[driverId] ?? [];
                      final salary =
                          (driver['monthly_salary'] as num?)?.toDouble() ?? 0;

                      double totalPaid = 0, totalWithdrawn = 0;
                      double totalBonus = 0,
                          totalOvertime = 0,
                          totalDeduction = 0;
                      for (final t in tx) {
                        final amt = (t['amount'] as num?)?.toDouble() ?? 0;
                        switch (t['type']) {
                          case 'payment':
                            totalPaid += amt;
                            break;
                          case 'withdrawal':
                            totalWithdrawn += amt;
                            break;
                          case 'bonus':
                            totalBonus += amt;
                            break;
                          case 'overtime':
                            totalOvertime += amt;
                            break;
                          case 'deduction':
                            totalDeduction += amt;
                            break;
                        }
                      }
                      // الرصيد المستحق = الراتب الأساسي (نقطة البداية) + مكافآت + أوفر تايم
                      // - مدفوع - سحوبات - خصميات
                      final netBalance = salary +
                          totalBonus +
                          totalOvertime -
                          totalPaid -
                          totalWithdrawn -
                          totalDeduction;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(driver['name'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                  ),
                                  GestureDetector(
                                    onTap: () => _editSalary(driver),
                                    child: Row(
                                      children: [
                                        Text(
                                            '${salary.toStringAsFixed(0)} ر.س/شهرياً',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textMuted)),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.edit,
                                            size: 13, color: AppTheme.primary),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 14,
                                runSpacing: 8,
                                children: [
                                  _statChip(
                                      'المستلم', totalPaid, AppTheme.success),
                                  _statChip('السحوبات', totalWithdrawn,
                                      AppTheme.warning),
                                  if (totalBonus > 0)
                                    _statChip('المكافآت', totalBonus,
                                        Colors.deepPurple),
                                  if (totalOvertime > 0)
                                    _statChip('الأوفر تايم', totalOvertime,
                                        AppTheme.primary),
                                  if (totalDeduction > 0)
                                    _statChip('الخصميات', totalDeduction,
                                        AppTheme.destructive),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'الرصيد المستحق: ${netBalance.toStringAsFixed(0)} ر.س',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: netBalance >= 0
                                      ? AppTheme.success
                                      : AppTheme.destructive,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _openLedger(driver),
                                  icon:
                                      const Icon(Icons.receipt_long, size: 16),
                                  label: Text('سجل الحركات (${tx.length})'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _statChip(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        Text('${value.toStringAsFixed(0)} ر.س',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// ============================================================
// سجل حركات السائق: دفعات وسحوبات + إضافة حركة جديدة
// ============================================================
class _DriverLedgerSheet extends StatefulWidget {
  final Map<String, dynamic> driver;
  final List<Map<String, dynamic>> transactions;
  final VoidCallback onChanged;

  const _DriverLedgerSheet({
    required this.driver,
    required this.transactions,
    required this.onChanged,
  });

  @override
  State<_DriverLedgerSheet> createState() => _DriverLedgerSheetState();
}

class _DriverLedgerSheetState extends State<_DriverLedgerSheet> {
  final supabase = Supabase.instance.client;
  late List<Map<String, dynamic>> _tx;
  bool _isSaving = false;

  String _type = 'payment';
  final _amountController = TextEditingController();
  final _periodController = TextEditingController();
  final _noteController = TextEditingController();
  final _dateController = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10));

  @override
  void initState() {
    super.initState();
    _tx = List.from(widget.transactions);
  }

  Future<void> _addTransaction() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;
    setState(() => _isSaving = true);
    try {
      final inserted = await supabase
          .from('driver_salary_transactions')
          .insert({
            'driver_id': widget.driver['id'].toString(),
            'driver_name': widget.driver['name'],
            'type': _type,
            'amount': amount,
            'transaction_date': _dateController.text.trim(),
            'period_label': _periodController.text.trim(),
            'note': _noteController.text.trim(),
          })
          .select()
          .single();

      setState(() {
        _tx.insert(0, inserted);
        _amountController.clear();
        _periodController.clear();
        _noteController.clear();
      });
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTransaction(Map<String, dynamic> t) async {
    await supabase
        .from('driver_salary_transactions')
        .delete()
        .eq('id', t['id']);
    setState(() => _tx.removeWhere((e) => e['id'] == t['id']));
    widget.onChanged();
  }

  Widget _typeChip(String value, String label, IconData icon, Color color) {
    final selected = _type == value;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _type = value),
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : color),
      label: Text(label),
      labelStyle:
          TextStyle(color: selected ? Colors.white : color, fontSize: 12),
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('سجل رواتب: ${widget.driver['name']}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // ---- إضافة حركة جديدة ----
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _typeChip('payment', 'دفعة راتب', Icons.payments,
                        AppTheme.success),
                    _typeChip('withdrawal', 'سحب مقدم / سلفة', Icons.money_off,
                        AppTheme.warning),
                    _typeChip('bonus', 'مكافأة', Icons.card_giftcard,
                        Colors.deepPurple),
                    _typeChip('overtime', 'أوفر تايم', Icons.schedule,
                        AppTheme.primary),
                    _typeChip('deduction', 'خصم', Icons.remove_circle_outline,
                        AppTheme.destructive),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  (_type == 'bonus' || _type == 'overtime')
                      ? 'يُضاف هذا المبلغ لمستحقات السائق'
                      : 'يُخصم هذا المبلغ من مستحقات السائق',
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'المبلغ', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _dateController,
                        decoration: const InputDecoration(
                            labelText: 'التاريخ (YYYY-MM-DD)',
                            border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _periodController,
                  decoration: const InputDecoration(
                    labelText: 'حق المدة (مثال: شهر يناير، أو من 1 إلى 15)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                      labelText: 'ملاحظة (اختياري)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _addTransaction,
                  icon: const Icon(Icons.add),
                  label: Text(_isSaving ? 'جارٍ الحفظ...' : 'تسجيل الحركة'),
                ),

                const SizedBox(height: 20),
                const Divider(),
                const Text('سجل الحركات',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                if (_tx.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text('لا توجد حركات مسجلة بعد',
                            style: TextStyle(color: AppTheme.textMuted))),
                  )
                else
                  ..._tx.map((t) {
                    final info = _typeInfo(t['type']?.toString() ?? 'payment');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(info.icon, color: info.color),
                        title: Text(
                            '${(t['amount'] as num).toStringAsFixed(0)} ر.س'
                            ' - ${info.label}'),
                        subtitle: Text(
                          '${t['transaction_date'] ?? ''}'
                          '${(t['period_label']?.toString().isNotEmpty ?? false) ? " • ${t['period_label']}" : ""}'
                          '${(t['note']?.toString().isNotEmpty ?? false) ? "\n${t['note']}" : ""}',
                        ),
                        isThreeLine:
                            (t['note']?.toString().isNotEmpty ?? false),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () => _deleteTransaction(t),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TypeInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _TypeInfo(this.label, this.icon, this.color);
}

_TypeInfo _typeInfo(String type) {
  switch (type) {
    case 'payment':
      return const _TypeInfo('دفعة راتب', Icons.payments, AppTheme.success);
    case 'withdrawal':
      return const _TypeInfo('سحب مقدم', Icons.money_off, AppTheme.warning);
    case 'bonus':
      return const _TypeInfo('مكافأة', Icons.card_giftcard, Colors.deepPurple);
    case 'overtime':
      return const _TypeInfo('أوفر تايم', Icons.schedule, AppTheme.primary);
    case 'deduction':
      return const _TypeInfo(
          'خصم', Icons.remove_circle_outline, AppTheme.destructive);
    default:
      return const _TypeInfo('حركة', Icons.receipt, AppTheme.textMuted);
  }
}
