import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountStatementScreen extends StatefulWidget {
  const AccountStatementScreen({super.key});

  @override
  State<AccountStatementScreen> createState() => _AccountStatementScreenState();
}

class _AccountStatementScreenState extends State<AccountStatementScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> ownersList = [];
  String? selectedOwnerId;
  List<Map<String, dynamic>> ownerOperations = [];
  bool isLoading = false;
  double totalOwnerDues = 0.0;

  @override
  void initState() {
    super.initState();
    fetchOwners();
  }

  Future<void> fetchOwners() async {
    try {
      final response = await supabase.from('owners').select();
      setState(() {
        ownersList = List<Map<String, dynamic>>.from(response);
      });
    } catch (_) {}
  }

  Future<void> fetchOwnerStatement(String ownerId) async {
    setState(() => isLoading = true);
    try {
      // افتراض وجود عمود owner_id في جدول operations لربط العمليات بالمالك
      final response =
          await supabase.from('operations').select().eq('owner_id', ownerId);

      double total = 0;
      for (var op in response) {
        total += (op['owner_net'] ?? 0) as num;
      }

      setState(() {
        ownerOperations = List<Map<String, dynamic>>.from(response);
        totalOwnerDues = total;
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
        title: const Text('كشف حساب الملاك والموردين'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F4C81),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'اختر المالك / المورد',
                border: OutlineInputBorder(),
              ),
              items: ownersList.map((owner) {
                return DropdownMenuItem<String>(
                  value: owner['id'].toString(),
                  child: Text(owner['name'] ?? ''),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => selectedOwnerId = val);
                  fetchOwnerStatement(val);
                }
              },
            ),
            const SizedBox(height: 20),
            if (selectedOwnerId != null) ...[
              Card(
                color: const Color(0xFF0F4C81),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('إجمالي المستحقات للمالك',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text('$totalOwnerDues ر.س',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('سجل الحركات التفصيلي:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ownerOperations.isEmpty
                        ? const Center(
                            child: Text('لا توجد حركات مسجلة لهذا المالك',
                                style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: ownerOperations.length,
                            itemBuilder: (context, index) {
                              final item = ownerOperations[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(
                                      Icons.account_balance_wallet,
                                      color: Color(0xFF0F4C81)),
                                  title: Text(
                                      'صافي المالك: ${item['owner_net'] ?? 0} ر.س'),
                                  subtitle: Text(
                                      'إيراد العملية: ${item['revenue'] ?? 0} ر.س'),
                                ),
                              );
                            },
                          ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Text('الرجاء اختيار مالك لعرض كشف الحساب المفصل',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
