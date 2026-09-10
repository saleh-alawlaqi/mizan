import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

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

  List<FlSpot> _weeklyChartSpots = [];
  double _maxChartY = 1000;
  List<String> _weekDaysLabels = [];

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
          .limit(100);

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

      Map<String, double> weeklyMap = {};
      List<String> daysKeys = [];
      for (int i = 6; i >= 0; i--) {
        final d = today.subtract(Duration(days: i));
        final key = d.toIso8601String().substring(0, 10);
        daysKeys.add(key);
        _weekDaysLabels.add(_getDayName(d.weekday));
        weeklyMap[key] = 0.0;
      }

      for (final op in ops) {
        final opDate = op['date']?.toString();
        if (opDate != null && weeklyMap.containsKey(opDate)) {
          weeklyMap[opDate] =
              (weeklyMap[opDate]! + ((op['revenue'] ?? 0) as num).toDouble());
        }
      }

      List<FlSpot> spots = [];
      double maxVal = 1000;
      for (int i = 0; i < daysKeys.length; i++) {
        double val = weeklyMap[daysKeys[i]] ?? 0;
        spots.add(FlSpot(i.toDouble(), val));
        if (val > maxVal) maxVal = val;
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
          _weeklyChartSpots = spots;
          _maxChartY = maxVal * 1.2;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getDayName(int weekday) {
    const days = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    return days[weekday - 1];
  }

  String _fmt(num? v) => '${(v ?? 0).toStringAsFixed(0)} ر.س';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    if (screenWidth > 1200) {
      crossAxisCount = 4;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _fetchAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'لوحة التحكم والإحصائيات',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'متابعة تفصيلية للأداء المالي والتشغيلي',
                      style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.bolt_rounded,
                          size: 18, color: AppTheme.primary),
                      SizedBox(width: 6),
                      Text(
                        'مباشر',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.9,
              children: [
                _buildDistinctiveKpiCard(
                  title: 'إيراد اليوم',
                  value: _fmt(_todayRevenue),
                  icon: Icons.payments_rounded,
                  color: AppTheme.primary,
                  bgColor: AppTheme.primaryLight,
                ),
                _buildDistinctiveKpiCard(
                  title: 'مستحقات المالك',
                  value: _fmt(_todayOwnerNet),
                  icon: Icons.account_balance_wallet_rounded,
                  color: Colors.teal,
                  bgColor: Colors.teal.shade50,
                ),
                _buildDistinctiveKpiCard(
                  title: 'مستحقات السائقين',
                  value: _fmt(_todayDriverNet),
                  icon: Icons.trending_up_rounded,
                  color: Colors.amber.shade800,
                  bgColor: Colors.amber.shade50,
                ),
                _buildDistinctiveKpiCard(
                  title: 'المعدات النشطة',
                  value: '$_equipmentCount',
                  icon: Icons.local_shipping_rounded,
                  color: Colors.indigo,
                  bgColor: Colors.indigo.shade50,
                ),
                _buildDistinctiveKpiCard(
                  title: 'إجمالي المشاريع',
                  value: '$_projectsCount',
                  icon: Icons.folder_special_rounded,
                  color: Colors.deepPurple,
                  bgColor: Colors.deepPurple.shade50,
                ),
                _buildDistinctiveKpiCard(
                  title: 'إجمالي السائقين',
                  value: '$_driversCount',
                  icon: Icons.badge_rounded,
                  color: Colors.blueGrey,
                  bgColor: Colors.blueGrey.shade50,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // الرسم البياني بعد التعديل والتنظيم
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.show_chart_rounded,
                              size: 22, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text(
                            'تحليل إيرادات الأسبوع الأخير',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'آخر 7 أيام',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 1,
                          ),
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
                              reservedSize: 32,
                              interval: 1, // إظهار كل يوم بانتظام بدون تداخل
                              getTitlesWidget: (value, meta) {
                                int idx = value.toInt();
                                if (idx >= 0 && idx < _weekDaysLabels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      _weekDaysLabels[idx],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: 6,
                        minY: 0,
                        maxY: _maxChartY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _weeklyChartSpots,
                            isCurved: true,
                            color: AppTheme.primary,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppTheme.primary.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_maintenanceEquipment.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'تنبيهات صيانة المعدات',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ..._maintenanceEquipment.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.circle,
                                  size: 8, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text(
                                e['name']?.toString() ?? '',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            _buildSectionContainer(
              title: 'آخر العمليات المسجلة',
              icon: Icons.receipt_long_rounded,
              isEmpty: _recentOperations.isEmpty,
              emptyText: 'لا توجد عمليات مسجلة حتى الآن',
              child: Column(
                children: _recentOperations.map((op) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.local_shipping,
                                    size: 18, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  (op['project_name']?.toString().isNotEmpty ??
                                          false)
                                      ? op['project_name']
                                      : 'بدون مشروع',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _fmt(op['revenue']),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'المالك: ${_fmt(op['owner_net'])}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionContainer(
              title: 'مشاريع قيد التحصيل وتحليل نسب الدفع',
              icon: Icons.account_balance_wallet_rounded,
              isEmpty: _collectionProjects.isEmpty,
              emptyText: 'لا توجد مشاريع قيد التحصيل حالياً',
              child: Column(
                children: _collectionProjects.map((p) {
                  final contractValue =
                      (p['contract_value'] as num?)?.toDouble() ?? 1;
                  final received =
                      (p['received_amount'] as num?)?.toDouble() ?? 0;
                  final remaining = contractValue - received;
                  double progress = (received / contractValue).clamp(0.0, 1.0);

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              p['name']?.toString() ?? '',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary),
                            ),
                            Text(
                              'متبقي: ${_fmt(remaining)}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.primary),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('المحصل: ${_fmt(received)}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textMuted)),
                            Text('الإجمالي: ${_fmt(contractValue)}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistinctiveKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required bool isEmpty,
    required String emptyText,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 18, thickness: 1),
          isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      emptyText,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : child,
        ],
      ),
    );
  }
}
