import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/pdf_helper.dart';
import 'package:pdf/widgets.dart' as pw;

enum _PartyType { owner, driver }

class AccountStatementScreen extends StatefulWidget {
  const AccountStatementScreen({super.key});

  @override
  State<AccountStatementScreen> createState() => _AccountStatementScreenState();
}

class _AccountStatementScreenState extends State<AccountStatementScreen> {
  final supabase = Supabase.instance.client;
  _PartyType _partyType = _PartyType.driver;

  bool _isLoadingLists = true;
  List<Map<String, dynamic>> _owners = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _equipment = [];

  Map<String, dynamic>? _selectedOwner;
  Map<String, dynamic>? _selectedDriver;

  bool _isLoadingStatement = false;
  List<Map<String, dynamic>> _operations = [];
  List<Map<String, dynamic>> _paymentTx = [];
  double _totalEarned = 0;
  double _totalPaid = 0;
  double _totalWithdrawn = 0;
  double _totalBonus = 0;
  double _totalOvertime = 0;
  double _totalDeduction = 0;

  @override
  void initState() {
    super.initState();
    _fetchLists();
  }

  Future<void> _fetchLists() async {
    try {
      final owners = await supabase.from('owners').select();
      final drivers = await supabase.from('drivers').select();
      final equipment = await supabase.from('equipment').select();
      setState(() {
        _owners = List<Map<String, dynamic>>.from(owners);
        _drivers = List<Map<String, dynamic>>.from(drivers);
        _equipment = List<Map<String, dynamic>>.from(equipment);
        _isLoadingLists = false;
      });
    } catch (e) {
      setState(() => _isLoadingLists = false);
    }
  }

  Future<void> _fetchOwnerStatement(Map<String, dynamic> owner) async {
    setState(() => _isLoadingStatement = true);
    try {
      // نربط المالك بمعداته عن طريق اسم المالك المسجّل في جدول equipment
      final ownerEquipmentIds = _equipment
          .where((e) => (e['owner_name']?.toString() ?? '') == owner['name'])
          .map((e) => e['id'].toString())
          .toSet();

      final allOps = await supabase
          .from('operations')
          .select()
          .order('created_at', ascending: false);

      final ownerOps = (allOps as List)
          .where((op) =>
              ownerEquipmentIds.contains(op['equipment_id']?.toString()))
          .toList();

      double total = 0;
      for (final op in ownerOps) {
        total += (op['owner_net'] ?? 0) as num;
      }

      setState(() {
        _operations = List<Map<String, dynamic>>.from(ownerOps);
        _totalEarned = total;
        _paymentTx = [];
        _totalPaid = 0;
        _totalWithdrawn = 0;
        _totalBonus = 0;
        _totalOvertime = 0;
        _totalDeduction = 0;
        _isLoadingStatement = false;
      });
    } catch (e) {
      setState(() => _isLoadingStatement = false);
    }
  }

  Future<void> _fetchDriverStatement(Map<String, dynamic> driver) async {
    setState(() => _isLoadingStatement = true);
    try {
      final ops = await supabase
          .from('operations')
          .select()
          .eq('driver_id', driver['id'].toString())
          .order('created_at', ascending: false);

      final tx = await supabase
          .from('driver_salary_transactions')
          .select()
          .eq('driver_id', driver['id'].toString())
          .order('created_at', ascending: false);

      double earned = 0;
      for (final op in ops) {
        earned += (op['driver_net'] ?? 0) as num;
      }
      double paid = 0, withdrawn = 0, bonus = 0, overtime = 0, deduction = 0;
      for (final t in tx) {
        final amt = (t['amount'] as num?)?.toDouble() ?? 0;
        switch (t['type']) {
          case 'payment':
            paid += amt;
            break;
          case 'withdrawal':
            withdrawn += amt;
            break;
          case 'bonus':
            bonus += amt;
            break;
          case 'overtime':
            overtime += amt;
            break;
          case 'deduction':
            deduction += amt;
            break;
        }
      }

      setState(() {
        _operations = List<Map<String, dynamic>>.from(ops);
        _paymentTx = List<Map<String, dynamic>>.from(tx);
        _totalEarned = earned;
        _totalPaid = paid;
        _totalWithdrawn = withdrawn;
        _totalBonus = bonus;
        _totalOvertime = overtime;
        _totalDeduction = deduction;
        _isLoadingStatement = false;
      });
    } catch (e) {
      setState(() => _isLoadingStatement = false);
    }
  }

  String _fmt(num v) => '${v.toStringAsFixed(0)} ر.س';

  Future<void> _exportPdf() async {
    final partyName = _partyType == _PartyType.driver
        ? (_selectedDriver?['name']?.toString() ?? '')
        : (_selectedOwner?['name']?.toString() ?? '');
    final isFixed = _partyType == _PartyType.driver &&
        _selectedDriver?['contract_type'] == 'fixed';
    final baseSalary = isFixed
        ? ((_selectedDriver?['monthly_salary'] as num?)?.toDouble() ?? 0)
        : 0;
    final balance = _partyType == _PartyType.owner
        ? _totalEarned
        : ((isFixed ? baseSalary : _totalEarned) +
            _totalBonus +
            _totalOvertime -
            _totalPaid -
            _totalWithdrawn -
            _totalDeduction);

    await PdfHelper.buildAndPrint(
      title: 'كشف حساب: $partyName',
      fileName: 'كشف_حساب_$partyName.pdf',
      content: (font, fontBold) => [
        pw.Row(
          children: [
            PdfHelper.summaryCard(font, fontBold, 'الرصيد المستحق',
                '${balance.toStringAsFixed(0)} ر.س'),
            if (_partyType == _PartyType.driver) ...[
              pw.SizedBox(width: 10),
              PdfHelper.summaryCard(font, fontBold, 'المكتسب من العمليات',
                  '${_totalEarned.toStringAsFixed(0)} ر.س'),
              pw.SizedBox(width: 10),
              PdfHelper.summaryCard(font, fontBold, 'المدفوع',
                  '${_totalPaid.toStringAsFixed(0)} ر.س'),
            ],
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('سجل العمليات',
            style: pw.TextStyle(
                font: fontBold, fontSize: 13, color: PdfHelper.headerColor)),
        pw.SizedBox(height: 6),
        PdfHelper.table(
          font: font,
          fontBold: fontBold,
          headers: [
            'الإيراد',
            _partyType == _PartyType.owner ? 'صافي المالك' : 'صافي السائق'
          ],
          rows: _operations
              .map((op) => [
                    '${((op['revenue'] ?? 0) as num).toStringAsFixed(0)} ر.س',
                    '${((_partyType == _PartyType.owner ? op['owner_net'] : op['driver_net']) ?? 0).toStringAsFixed(0)} ر.س',
                  ])
              .toList(),
        ),
        if (_partyType == _PartyType.driver && _paymentTx.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('سجل الدفعات والسحوبات',
              style: pw.TextStyle(
                  font: fontBold, fontSize: 13, color: PdfHelper.headerColor)),
          pw.SizedBox(height: 6),
          PdfHelper.table(
            font: font,
            fontBold: fontBold,
            headers: ['التاريخ', 'النوع', 'المبلغ'],
            rows: _paymentTx
                .map((t) => [
                      t['transaction_date']?.toString() ?? '',
                      t['type'] == 'payment' ? 'دفعة' : 'سحب',
                      '${(t['amount'] as num).toStringAsFixed(0)} ر.س',
                    ])
                .toList(),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFixedDriver = _partyType == _PartyType.driver &&
        _selectedDriver?['contract_type'] == 'fixed';

    // الرصيد المتبقي: للسائق بالنسبة = مستحق من العمليات - المدفوع + السحوبات
    // للسائق بالراتب الثابت = المدفوع - السحوبات (الأساس الشهري يُدار من شاشة الرواتب)
    final double baseSalary = isFixedDriver
        ? ((_selectedDriver?['monthly_salary'] as num?)?.toDouble() ?? 0)
        : 0;
    final double balance = _partyType == _PartyType.owner
        ? _totalEarned
        : ((isFixedDriver ? baseSalary : _totalEarned) +
            _totalBonus +
            _totalOvertime -
            _totalPaid -
            _totalWithdrawn -
            _totalDeduction);

    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف حساب الملاك والسائقين'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primary,
        actions: [
          if (_selectedDriver != null || _selectedOwner != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primary),
              tooltip: 'تصدير PDF',
              onPressed: _exportPdf,
            ),
        ],
      ),
      body: _isLoadingLists
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<_PartyType>(
                    segments: const [
                      ButtonSegment(
                          value: _PartyType.driver, label: Text('سائق')),
                      ButtonSegment(
                          value: _PartyType.owner, label: Text('مالك معدة')),
                    ],
                    selected: {_partyType},
                    onSelectionChanged: (s) {
                      setState(() {
                        _partyType = s.first;
                        _selectedOwner = null;
                        _selectedDriver = null;
                        _operations = [];
                        _paymentTx = [];
                        _totalEarned = 0;
                        _totalPaid = 0;
                        _totalWithdrawn = 0;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_partyType == _PartyType.driver)
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedDriver,
                      decoration: const InputDecoration(
                          labelText: 'اختر السائق',
                          border: OutlineInputBorder()),
                      items: _drivers
                          .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text(d['name']?.toString() ?? '')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedDriver = val);
                          _fetchDriverStatement(val);
                        }
                      },
                    )
                  else
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedOwner,
                      decoration: const InputDecoration(
                          labelText: 'اختر المالك',
                          border: OutlineInputBorder()),
                      items: _owners
                          .map((o) => DropdownMenuItem(
                              value: o,
                              child: Text(o['name']?.toString() ?? '')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedOwner = val);
                          _fetchOwnerStatement(val);
                        }
                      },
                    ),
                  const SizedBox(height: 20),
                  if (_selectedDriver != null || _selectedOwner != null) ...[
                    Card(
                      color: AppTheme.primary,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text('الرصيد المستحق حالياً',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(_fmt(balance),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_partyType == _PartyType.driver)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _miniStat('المكتسب من العمليات', _totalEarned),
                          _miniStat('المدفوع', _totalPaid),
                          _miniStat('السحوبات', _totalWithdrawn),
                        ],
                      ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _isLoadingStatement
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                              children: [
                                const Text('سجل العمليات:',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                if (_operations.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Text('لا توجد عمليات مسجلة',
                                        style: TextStyle(
                                            color: AppTheme.textMuted)),
                                  )
                                else
                                  ..._operations.map((op) => Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          leading: const Icon(Icons.receipt,
                                              color: AppTheme.primary),
                                          title: Text(
                                              'إيراد: ${_fmt((op['revenue'] ?? 0) as num)}'),
                                          subtitle: Text(_partyType ==
                                                  _PartyType.owner
                                              ? 'صافي المالك: ${_fmt((op['owner_net'] ?? 0) as num)}'
                                              : 'صافي السائق: ${_fmt((op['driver_net'] ?? 0) as num)}'),
                                        ),
                                      )),
                                if (_partyType == _PartyType.driver &&
                                    _paymentTx.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Text('سجل الدفعات والسحوبات:',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  ..._paymentTx.map((t) => Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          leading: Icon(
                                            t['type'] == 'payment'
                                                ? Icons.arrow_downward
                                                : Icons.money_off,
                                            color: t['type'] == 'payment'
                                                ? AppTheme.success
                                                : AppTheme.warning,
                                          ),
                                          title: Text(
                                              _fmt((t['amount'] ?? 0) as num)),
                                          subtitle: Text(
                                              '${t['transaction_date'] ?? ''} - ${t['type'] == 'payment' ? 'دفعة' : 'سحب'}'),
                                        ),
                                      )),
                                ],
                              ],
                            ),
                    ),
                  ] else
                    const Expanded(
                      child: Center(
                        child: Text(
                            'الرجاء اختيار سائق أو مالك لعرض كشف الحساب',
                            style: TextStyle(color: AppTheme.textMuted)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _miniStat(String label, double value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        Text(_fmt(value),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
