import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectDetailsScreen({super.key, required this.project});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> projectOperations = [];
  bool isLoading = true;
  double totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    fetchProjectOperations();
  }

  Future<void> fetchProjectOperations() async {
    try {
      final response = await supabase
          .from('operations')
          .select()
          .eq('project_id', widget.project['id']);

      double rev = 0;
      for (var op in response) {
        rev += (op['revenue'] ?? 0) as num;
      }

      setState(() {
        projectOperations = List<Map<String, dynamic>>.from(response);
        totalRevenue = rev;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل مشروع: ${widget.project['name'] ?? ''}'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F4C81),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('اسم المشروع: ${widget.project['name'] ?? ''}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                              'الموقع: ${widget.project['location'] ?? 'غير متوفر'}',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey)),
                          const Divider(height: 24),
                          Text('إجمالي إيرادات المشروع: $totalRevenue ر.س',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F4C81))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('العمليات التشغيلية التابعة للمشروع:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: projectOperations.isEmpty
                        ? const Center(
                            child: Text('لا توجد عمليات مسجلة لهذا المشروع',
                                style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: projectOperations.length,
                            itemBuilder: (context, index) {
                              final op = projectOperations[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.receipt,
                                      color: Color(0xFF0F4C81)),
                                  title:
                                      Text('إيراد: ${op['revenue'] ?? 0} ر.س'),
                                  subtitle: Text(
                                      'المصروفات: ${op['total_expenses'] ?? 0} ر.س'),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
