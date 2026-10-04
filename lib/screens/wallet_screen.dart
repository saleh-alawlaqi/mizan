import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/pdf_helper.dart';
import 'package:pdf/widgets.dart' as pw;

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('wallet_transactions')
          .select()
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(res);
      double bal = 0;
      for (final t in list) {
        final amount = (t['amount'] as num?)?.toDouble() ?? 0;
        bal += t['type'] == 'deposit' ? amount : -amount;
      }
      setState(() {
        _transactions = list;
        _balance = bal;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showAddModal({required String type}) {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    final isDeposit = type == 'deposit';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(isDeposit ? 'إضافة إيداع' : 'تسجيل مصروف يدوي',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'المبلغ (ر.س)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                        labelText: 'الوصف (اختياري)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDeposit ? AppTheme.success : AppTheme.destructive,
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final amount =
                                double.tryParse(amountController.text.trim());
                            if (amount == null || amount <= 0) return;
                            setModalState(() => isSaving = true);
                            try {
                              await supabase
                                  .from('wallet_transactions')
                                  .insert({
                                'type': type,
                                'amount': amount,
                                'description': descController.text.trim(),
                                'date': DateTime.now()
                                    .toIso8601String()
                                    .substring(0, 10),
                              });
                              if (context.mounted) {
                                Navigator.pop(context);
                                _fetch();
                              }
                            } catch (e) {
                              setModalState(() => isSaving = false);
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(isDeposit ? 'إضافة الإيداع' : 'تسجيل المصروف'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportPdf() async {
    double totalDeposits = 0, totalExpenses = 0;
    for (final t in _transactions) {
      final amt = (t['amount'] as num?)?.toDouble() ?? 0;
      if (t['type'] == 'deposit') {
        totalDeposits += amt;
      } else {
        totalExpenses += amt;
      }
    }

    await PdfHelper.buildAndPrint(
      title: 'كشف محفظة المالك',
      fileName: 'كشف_محفظة_المالك.pdf',
      content: (font, fontBold) => [
        pw.Row(
          children: [
            PdfHelper.summaryCard(font, fontBold, 'الرصيد الحالي',
                '${_balance.toStringAsFixed(0)} ر.س'),
            pw.SizedBox(width: 10),
            PdfHelper.summaryCard(font, fontBold, 'إجمالي الإيداعات',
                '${totalDeposits.toStringAsFixed(0)} ر.س'),
            pw.SizedBox(width: 10),
            PdfHelper.summaryCard(font, fontBold, 'إجمالي المصاريف',
                '${totalExpenses.toStringAsFixed(0)} ر.س'),
          ],
        ),
        pw.SizedBox(height: 16),
        PdfHelper.table(
          font: font,
          fontBold: fontBold,
          headers: ['التاريخ', 'النوع', 'المبلغ', 'الوصف'],
          rows: _transactions
              .map((t) => [
                    t['date']?.toString() ?? '',
                    t['type'] == 'deposit' ? 'إيداع' : 'مصروف',
                    '${(t['amount'] as num).toStringAsFixed(0)} ر.س',
                    t['description']?.toString() ?? '',
                  ])
              .toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محفظة المالك'),
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
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text('الرصيد المتوفر حالياً',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text('${_balance.toStringAsFixed(2)} ر.س',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success),
                          onPressed: () => _showAddModal(type: 'deposit'),
                          icon: const Icon(Icons.add),
                          label: const Text('إيداع'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.destructive),
                          onPressed: () => _showAddModal(type: 'expense'),
                          icon: const Icon(Icons.remove),
                          label: const Text('مصروف'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('سجل الحركات',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                          child: Text('لا توجد حركات مسجلة',
                              style: TextStyle(color: AppTheme.textMuted))),
                    )
                  else
                    ..._transactions.map((t) {
                      final isDeposit = t['type'] == 'deposit';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            isDeposit
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isDeposit
                                ? AppTheme.success
                                : AppTheme.destructive,
                          ),
                          title: Text(
                            (t['description']?.toString().isNotEmpty ?? false)
                                ? t['description']
                                : (isDeposit ? 'إيداع' : 'مصروف'),
                          ),
                          subtitle: Text(t['date']?.toString() ?? ''),
                          trailing: Text(
                            '${isDeposit ? '+' : '-'}${(t['amount'] as num).toStringAsFixed(2)} ر.س',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDeposit
                                  ? AppTheme.success
                                  : AppTheme.destructive,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
