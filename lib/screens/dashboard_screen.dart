import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../utils/pdf_helper.dart';
import 'package:pdf/widgets.dart' as pw;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  double _todayRevenue = 0;
  double _todayOwnerNet = 0;
  double _todayDriverNet = 0;
  int _equipmentCount = 0;
  int _projectsCount = 0;
  int _driversCount = 0;

  List<Map<String, dynamic>> _recentOperations = [];
  List<Map<String, dynamic>> _collectionProjects = [];
  List<Map<String, dynamic>> _maintenanceEquipment = [];

  List<FlSpot> _weeklySpots = [];
  List<String> _weekDayLabels = [];
  double _maxChartY = 1000;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().substring(0, 10);

      final ops = await supabase
          .from('operations')
          .select()
          .order('created_at', ascending: false)
          .limit(200);

      final equipment = await supabase.from('equipment').select();
      final projects = await supabase.from('projects').select();
      final drivers = await supabase.from('drivers').select();

      double todayRev = 0, todayOwner = 0, todayDriver = 0;
      for (final op in ops) {
        if (op['date'] == todayStr) {
          todayRev += (op['revenue'] ?? 0) as num;
          todayOwner += (op['owner_net'] ?? 0) as num;
          todayDriver += (op['driver_net'] ?? 0) as num;
        }
      }

      // بيانات آخر 7 أيام للرسم البياني
      final dayKeys = <String>[];
      final dayLabels = <String>[];
      for (int i = 6; i >= 0; i--) {
        final d = today.subtract(Duration(days: i));
        dayKeys.add(d.toIso8601String().substring(0, 10));
        dayLabels.add(_weekdayShort(d.weekday));
      }
      final revByDay = {for (final k in dayKeys) k: 0.0};
      for (final op in ops) {
        final d = op['date']?.toString();
        if (d != null && revByDay.containsKey(d)) {
          revByDay[d] = revByDay[d]! + ((op['revenue'] ?? 0) as num).toDouble();
        }
      }
      final spots = <FlSpot>[];
      double maxVal = 500;
      for (int i = 0; i < dayKeys.length; i++) {
        final v = revByDay[dayKeys[i]] ?? 0;
        spots.add(FlSpot(i.toDouble(), v));
        if (v > maxVal) maxVal = v;
      }

      final collectionProjects = (projects as List).where((p) {
        final contractValue = (p['contract_value'] as num?)?.toDouble() ?? 0;
        final received = (p['received_amount'] as num?)?.toDouble() ?? 0;
        return contractValue > 0 &&
            received < contractValue &&
            p['closed'] != true;
      }).toList();

      final maintenanceEquipment = (equipment as List)
          .where((e) => e['status'] == 'maintenance' || e['status'] == 'صيانة')
          .toList();

      if (mounted) {
        setState(() {
          _todayRevenue = todayRev;
          _todayOwnerNet = todayOwner;
          _todayDriverNet = todayDriver;
          _equipmentCount = equipment.length;
          _projectsCount = projects.length;
          _driversCount = drivers.length;
          _recentOperations =
              List<Map<String, dynamic>>.from(ops).take(5).toList();
          _collectionProjects =
              List<Map<String, dynamic>>.from(collectionProjects);
          _maintenanceEquipment =
              List<Map<String, dynamic>>.from(maintenanceEquipment);
          _weeklySpots = spots;
          _weekDayLabels = dayLabels;
          _maxChartY = maxVal * 1.25;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _weekdayShort(int weekday) {
    const names = ['اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];
    return names[weekday - 1];
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 17) return 'مساء الخير';
    return 'مساء الخير';
  }

  String _fmt(num? v) => '${(v ?? 0).toStringAsFixed(0)} ر.س';

  Future<void> _exportPdf() async {
    await PdfHelper.buildAndPrint(
      title: 'تطبيق ميزان - تقرير لوحة التحكم',
      fileName: 'تقرير_لوحة_التحكم.pdf',
      content: (font, fontBold) => [
        pw.Row(
          children: [
            PdfHelper.summaryCard(font, fontBold, 'إيراد اليوم',
                '${_todayRevenue.toStringAsFixed(0)} ر.س'),
            pw.SizedBox(width: 10),
            PdfHelper.summaryCard(font, fontBold, 'مستحقات المالك',
                '${_todayOwnerNet.toStringAsFixed(0)} ر.س'),
            pw.SizedBox(width: 10),
            PdfHelper.summaryCard(font, fontBold, 'مستحقات السائقين',
                '${_todayDriverNet.toStringAsFixed(0)} ر.س'),
          ],
        ),
        pw.SizedBox(height: 16),
        PdfHelper.table(
          font: font,
          fontBold: fontBold,
          headers: ['البيان', 'العدد'],
          rows: [
            ['عدد المعدات', '$_equipmentCount'],
            ['عدد السائقين', '$_driversCount'],
            ['عدد المشاريع', '$_projectsCount'],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    return Scaffold(
        appBar: AppBar(
          title: const Text('لوحة التحكم'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primary),
              tooltip: 'تصدير PDF',
              onPressed: _exportPdf,
            ),
          ],
        ),
        body: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: _fetchAll,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ==================== ترويسة ترحيبية بتدرج لوني ====================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(),
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          const Text('لوحة التحكم',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          Text('إيراد اليوم: ${_fmt(_todayRevenue)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ==================== شبكة مؤشرات الأداء ====================
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.0,
                children: [
                  KpiCard(
                    label: 'مستحقات المالك اليوم',
                    value: _fmt(_todayOwnerNet),
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppTheme.success,
                    bgColor: AppTheme.successLight,
                  ),
                  KpiCard(
                    label: 'مستحقات السائقين اليوم',
                    value: _fmt(_todayDriverNet),
                    icon: Icons.payments_rounded,
                    color: AppTheme.warning,
                    bgColor: AppTheme.warningLight,
                  ),
                  KpiCard(
                    label: 'عدد المعدات',
                    value: '$_equipmentCount',
                    icon: Icons.local_shipping_rounded,
                    color: AppTheme.primary,
                    bgColor: AppTheme.primaryLight,
                  ),
                  KpiCard(
                    label: 'عدد السائقين',
                    value: '$_driversCount',
                    icon: Icons.badge_rounded,
                    color: AppTheme.purple,
                    bgColor: AppTheme.purpleLight,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ==================== الرسم البياني الأسبوعي ====================
              SectionCard(
                title: 'تحليل إيرادات آخر 7 أيام',
                icon: Icons.show_chart_rounded,
                trailing: _projectsCount > 0
                    ? StatusBadge(
                        label: '$_projectsCount مشروع',
                        color: AppTheme.primary,
                      )
                    : null,
                child: SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _maxChartY / 4,
                        getDrawingHorizontalLine: (value) =>
                            FlLine(color: AppTheme.border, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= _weekDayLabels.length)
                                return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(_weekDayLabels[idx],
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textMuted)),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 6,
                      minY: 0,
                      maxY: _maxChartY,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (touchedSpot) =>
                              AppTheme.primaryDark,
                          getTooltipItems: (spots) => spots
                              .map((s) => LineTooltipItem(
                                  '${s.y.toStringAsFixed(0)} ر.س',
                                  const TextStyle(
                                      color: Colors.white, fontSize: 11)))
                              .toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _weeklySpots,
                          isCurved: true,
                          color: AppTheme.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                              radius: 4,
                              color: AppTheme.primary,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.primary.withValues(alpha: 0.25),
                                AppTheme.primary.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ==================== آخر العمليات ====================
              SectionCard(
                title: 'آخر العمليات',
                icon: Icons.receipt_long_rounded,
                child: _recentOperations.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        message: 'لا توجد عمليات مسجلة بعد')
                    : Column(
                        children: _recentOperations.map((op) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.local_shipping,
                                      size: 16, color: AppTheme.primary),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    (op['project_name']
                                                ?.toString()
                                                .isNotEmpty ??
                                            false)
                                        ? op['project_name']
                                        : 'بدون مشروع',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(_fmt(op['revenue']),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary)),
                                    Text('المالك: ${_fmt(op['owner_net'])}',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.textMuted)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),

              // ==================== مشاريع قيد التحصيل ====================
              SectionCard(
                title: 'مشاريع قيد التحصيل',
                icon: Icons.account_balance_wallet_rounded,
                child: _collectionProjects.isEmpty
                    ? const EmptyState(
                        icon: Icons.check_circle_outline,
                        message: 'لا توجد مشاريع قيد التحصيل')
                    : Column(
                        children: _collectionProjects.map((p) {
                          final contractValue =
                              (p['contract_value'] as num?)?.toDouble() ?? 1;
                          final received =
                              (p['received_amount'] as num?)?.toDouble() ?? 0;
                          final remaining = contractValue - received;
                          final progress =
                              (received / contractValue).clamp(0.0, 1.0);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(p['name']?.toString() ?? '',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text('متبقي ${_fmt(remaining)}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.warning)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 7,
                                    backgroundColor: AppTheme.border,
                                    valueColor: const AlwaysStoppedAnimation(
                                        AppTheme.primary),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),

              // ==================== تنبيهات الصيانة ====================
              if (_maintenanceEquipment.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.3)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: AppTheme.warning, size: 20),
                          SizedBox(width: 8),
                          Text('تنبيهات الصيانة',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.warning)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._maintenanceEquipment.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                const Icon(Icons.local_shipping,
                                    size: 15, color: AppTheme.warning),
                                const SizedBox(width: 8),
                                Text(e['name']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ));
  }
}
