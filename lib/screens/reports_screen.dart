import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _Period { daily, monthly, yearly, custom }

class _ReportsScreenState extends State<ReportsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  _Period _period = _Period.monthly;
  DateTime _customFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _customTo = DateTime.now();

  List<Map<String, dynamic>> _allOperations = [];
  List<Map<String, dynamic>> _filteredOperations = [];

  double totalRevenue = 0;
  double totalOwnerNet = 0;
  double totalDriverNet = 0;
  double totalExpenses = 0;
  double totalSharedExpense = 0;

  Map<String, double> _revenueByEquipment = {};
  Map<String, double> _revenueByDriver = {};
  Map<String, double> _revenueByProject = {};

  @override
  void initState() {
    super.initState();
    fetchReportsData();
  }

  Future<void> fetchReportsData() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('operations')
          .select()
          .order('created_at', ascending: false);
      _allOperations = List<Map<String, dynamic>>.from(response);
      _applyFilter();
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    _filteredOperations = _allOperations.where((op) {
      final dateStr = op['date']?.toString();
      if (dateStr == null || dateStr.length < 7) return true;
      DateTime? d;
      try {
        d = DateTime.parse(dateStr);
      } catch (_) {
        return true;
      }
      switch (_period) {
        case _Period.daily:
          return d.year == now.year && d.month == now.month && d.day == now.day;
        case _Period.monthly:
          return d.year == now.year && d.month == now.month;
        case _Period.yearly:
          return d.year == now.year;
        case _Period.custom:
          final from =
              DateTime(_customFrom.year, _customFrom.month, _customFrom.day);
          final to = DateTime(
              _customTo.year, _customTo.month, _customTo.day, 23, 59, 59);
          return !d.isBefore(from) && !d.isAfter(to);
      }
    }).toList();

    double rev = 0, owner = 0, driver = 0, exp = 0, shared = 0;
    final byEquipment = <String, double>{};
    final byDriver = <String, double>{};
    final byProject = <String, double>{};

    for (final op in _filteredOperations) {
      rev += (op['revenue'] ?? 0) as num;
      owner += (op['owner_net'] ?? 0) as num;
      driver += (op['driver_net'] ?? 0) as num;
      exp += (op['total_expenses'] ?? 0) as num;
      shared += (op['shared_expense'] ?? 0) as num;

      final eqName = (op['equipment_name']?.toString().isNotEmpty ?? false)
          ? op['equipment_name'].toString()
          : 'غير محدد';
      final drName = (op['driver_name']?.toString().isNotEmpty ?? false)
          ? op['driver_name'].toString()
          : 'غير محدد';
      final prName = (op['project_name']?.toString().isNotEmpty ?? false)
          ? op['project_name'].toString()
          : 'بدون مشروع';

      byEquipment[eqName] =
          (byEquipment[eqName] ?? 0) + ((op['revenue'] ?? 0) as num);
      byDriver[drName] =
          (byDriver[drName] ?? 0) + ((op['revenue'] ?? 0) as num);
      byProject[prName] =
          (byProject[prName] ?? 0) + ((op['revenue'] ?? 0) as num);
    }

    setState(() {
      totalRevenue = rev;
      totalOwnerNet = owner;
      totalDriverNet = driver;
      totalExpenses = exp;
      totalSharedExpense = shared;
      _revenueByEquipment = byEquipment;
      _revenueByDriver = byDriver;
      _revenueByProject = byProject;
      isLoading = false;
    });
  }

  String _fmt(num v) => '${v.toStringAsFixed(0)} ر.س';

  String get _periodLabel {
    switch (_period) {
      case _Period.daily:
        return 'اليوم';
      case _Period.monthly:
        return 'هذا الشهر';
      case _Period.yearly:
        return 'هذي السنة';
      case _Period.custom:
        final f = _customFrom.toIso8601String().substring(0, 10);
        final t = _customTo.toIso8601String().substring(0, 10);
        return 'من $f إلى $t';
    }
  }

  // ==================== تصدير PDF احترافي بجداول ====================
  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final headerColor = PdfColor.fromInt(0xFF086591); // AppTheme.primary
    final altRowColor = PdfColor.fromInt(0xFFF3F6F9);

    pw.Widget sectionTitle(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
          child: pw.Text(text,
              style: pw.TextStyle(
                  font: fontBold, fontSize: 14, color: headerColor)),
        );

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

    List<List<String>> breakdownRows(Map<String, double> data) {
      final sorted = data.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted
          .map((e) => [e.key, '${e.value.toStringAsFixed(0)} ر.س'])
          .toList();
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
                  pw.Text('تقرير ميزان المالي - $_periodLabel',
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
              children: [
                dataTable(
                  ['البيان', 'القيمة'],
                  [
                    ['إجمالي الإيرادات', _fmt(totalRevenue)],
                    ['إجمالي مصاريف المالك', _fmt(totalExpenses)],
                    ['المصاريف المشتركة', _fmt(totalSharedExpense)],
                    ['صافي الملاك', _fmt(totalOwnerNet)],
                    ['مستحقات السائقين', _fmt(totalDriverNet)],
                    ['عدد العمليات', '${_filteredOperations.length}'],
                  ],
                ),
                sectionTitle('الإيراد حسب المعدة'),
                dataTable(
                    ['المعدة', 'الإيراد'], breakdownRows(_revenueByEquipment)),
                sectionTitle('الإيراد حسب السائق'),
                dataTable(
                    ['السائق', 'الإيراد'], breakdownRows(_revenueByDriver)),
                sectionTitle('الإيراد حسب المشروع'),
                dataTable(
                    ['المشروع', 'الإيراد'], breakdownRows(_revenueByProject)),
              ],
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
      name: 'تقرير_ميزان_$_periodLabel.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primary),
            tooltip: 'تصدير PDF',
            onPressed: isLoading ? null : _exportPdf,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchReportsData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('التقارير المالية والتشغيلية',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  const Text('ملخص أداء العمليات المسجلة في النظام',
                      style:
                          TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_Period>(
                      segments: const [
                        ButtonSegment(
                            value: _Period.daily, label: Text('اليوم')),
                        ButtonSegment(
                            value: _Period.monthly, label: Text('هذا الشهر')),
                        ButtonSegment(
                            value: _Period.yearly, label: Text('هذي السنة')),
                        ButtonSegment(
                            value: _Period.custom, label: Text('مخصّص')),
                      ],
                      selected: {_period},
                      onSelectionChanged: (selection) async {
                        final chosen = selection.first;
                        if (chosen == _Period.custom) {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 1)),
                            initialDateRange: DateTimeRange(
                                start: _customFrom, end: _customTo),
                          );
                          if (range == null) return; // المستخدم لغى الاختيار
                          setState(() {
                            _customFrom = range.start;
                            _customTo = range.end;
                            _period = _Period.custom;
                          });
                        } else {
                          setState(() => _period = chosen);
                        }
                        _applyFilter();
                      },
                    ),
                  ),
                  if (_period == _Period.custom) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                          initialDateRange:
                              DateTimeRange(start: _customFrom, end: _customTo),
                        );
                        if (range == null) return;
                        setState(() {
                          _customFrom = range.start;
                          _customTo = range.end;
                        });
                        _applyFilter();
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.date_range,
                              size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(_periodLabel,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit,
                              size: 12, color: AppTheme.primary),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.1,
                    children: [
                      KpiCard(
                        label: 'إجمالي الإيرادات',
                        value: _fmt(totalRevenue),
                        icon: Icons.trending_up,
                        color: AppTheme.primary,
                        bgColor: AppTheme.primaryLight,
                      ),
                      KpiCard(
                        label: 'إجمالي مصاريف المالك',
                        value: _fmt(totalExpenses),
                        icon: Icons.trending_down,
                        color: AppTheme.destructive,
                        bgColor: AppTheme.destructiveLight,
                      ),
                      KpiCard(
                        label: 'صافي الملاك',
                        value: _fmt(totalOwnerNet),
                        icon: Icons.account_balance,
                        color: AppTheme.success,
                        bgColor: AppTheme.successLight,
                      ),
                      KpiCard(
                        label: 'مستحقات السائقين',
                        value: _fmt(totalDriverNet),
                        icon: Icons.payments,
                        color: AppTheme.warning,
                        bgColor: AppTheme.warningLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _tableSection('الإيراد حسب المعدة', Icons.local_shipping,
                      _revenueByEquipment),
                  const SizedBox(height: 16),
                  _tableSection(
                      'الإيراد حسب السائق', Icons.badge, _revenueByDriver),
                  const SizedBox(height: 16),
                  _tableSection('الإيراد حسب المشروع', Icons.folder_open,
                      _revenueByProject),
                  const SizedBox(height: 16),
                  Text(
                      'عدد العمليات في هذي الفترة: ${_filteredOperations.length}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
    );
  }

  /// قسم جدول ملوّن ومرتّب داخل التطبيق (مو بس أشرطة تقدّم)
  Widget _tableSection(String title, IconData icon, Map<String, double> data) {
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold(0.0, (s, e) => s + e.value);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.primary,
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                Text(_fmt(total),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Text('لا توجد بيانات',
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 13))),
            )
          else
            ...List.generate(sorted.length, (i) {
              final entry = sorted[i];
              final isEven = i % 2 == 0;
              final ratio = total == 0 ? 0.0 : entry.value / total;
              return Container(
                color: isEven ? Colors.white : AppTheme.background,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(entry.key,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textPrimary)),
                    ),
                    Expanded(
                      flex: 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: AppTheme.border,
                          valueColor:
                              const AlwaysStoppedAnimation(AppTheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 80,
                      child: Text(
                        _fmt(entry.value),
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
