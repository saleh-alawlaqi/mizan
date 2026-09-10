import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  double totalRevenue = 0.0;
  double totalExpenses = 0.0;
  double totalOwnerNet = 0.0;
  double totalDriverNet = 0.0;

  @override
  void initState() {
    super.initState();
    fetchReportsData();
  }

  Future<void> fetchReportsData() async {
    try {
      final response = await supabase.from('operations').select();

      double rev = 0.0;
      double exp = 0.0;
      double owner = 0.0;
      double driver = 0.0;

      for (var item in response) {
        rev += (item['revenue'] ?? 0.0) as num;
        exp += (item['total_expenses'] ?? 0.0) as num;
        owner += (item['owner_net'] ?? 0.0) as num;
        driver += (item['driver_net'] ?? 0.0) as num;
      }

      setState(() {
        totalRevenue = rev;
        totalExpenses = exp;
        totalOwnerNet = owner;
        totalDriverNet = driver;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchReportsData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'التقارير المالية والتشغيلية',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ملخص أداء العمليات المسجلة في النظام',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  _buildReportCard('إجمالي الإيرادات', '$totalRevenue ر.س',
                      Icons.trending_up, Colors.blue),
                  const SizedBox(height: 12),
                  _buildReportCard('إجمالي المصروفات', '$totalExpenses ر.س',
                      Icons.trending_down, Colors.red),
                  const SizedBox(height: 12),
                  _buildReportCard('إجمالي صافي الملاك', '$totalOwnerNet ر.س',
                      Icons.account_balance, Colors.teal),
                  const SizedBox(height: 12),
                  _buildReportCard('إجمالي مستحقات السائقين',
                      '$totalDriverNet ر.س', Icons.payments, Colors.amber),
                ],
              ),
            ),
    );
  }

  Widget _buildReportCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
