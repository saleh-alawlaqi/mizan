import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> driversList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDrivers();
  }

  Future<void> fetchDrivers() async {
    try {
      final response = await supabase
          .from('drivers')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        driversList = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      print('خطأ جلب السائقين: $e');
      setState(() => isLoading = false);
    }
  }

  void _showAddDriverModal(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String contractType = 'ratio'; // ratio, fixed, daily
    final salaryController = TextEditingController(text: '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('إضافة سائق جديد',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                            labelText: 'اسم السائق',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                            labelText: 'رقم الجوال',
                            border: OutlineInputBorder()),
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: contractType,
                      decoration: const InputDecoration(
                          labelText: 'نوع العقد / السائق',
                          border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(
                            value: 'ratio', child: Text('نسبة مئوية')),
                        DropdownMenuItem(
                            value: 'fixed', child: Text('راتب شهري ثابت')),
                        DropdownMenuItem(
                            value: 'daily', child: Text('سائق يوميات (مؤقت)')),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          contractType = val!;
                        });
                      },
                    ),
                    if (contractType == 'fixed') ...[
                      const SizedBox(height: 12),
                      TextField(
                          controller: salaryController,
                          decoration: const InputDecoration(
                              labelText: 'قيمة الراتب الشهري',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.number),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F4C81),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () async {
                        if (nameController.text.isNotEmpty) {
                          try {
                            // إرسال البيانات بالإنجليزية والـ values الأساسية
                            await supabase.from('drivers').insert({
                              'name': nameController.text.trim(),
                              'phone': phoneController.text.trim().isEmpty
                                  ? null
                                  : phoneController.text.trim(),
                              'contract_type': contractType,
                              'monthly_salary': contractType == 'fixed'
                                  ? (double.tryParse(salaryController.text) ??
                                      0)
                                  : 0,
                            });

                            Navigator.pop(context);
                            fetchDrivers();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم إضافة السائق بنجاح'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            print('خطأ تفصيلي أثناء الحفظ: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('خطأ أثناء الحفظ: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('حفظ السائق',
                          style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : driversList.isEmpty
              ? const Center(
                  child: Text('لا توجد سائقين مسجلين حالياً',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: driversList.length,
                  itemBuilder: (context, index) {
                    final item = driversList[index];
                    final cType = item['contract_type'];
                    String typeText = 'نسبة';
                    if (cType == 'fixed') {
                      typeText = "راتب شهري (${item['monthly_salary']} ر.س)";
                    } else if (cType == 'daily') {
                      typeText = "سائق يوميات";
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading:
                            const Icon(Icons.badge, color: Color(0xFF0F4C81)),
                        title: Text(item['name'] ?? 'بدون اسم',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'الجوال: ${item['phone'] ?? 'غير متوفر'} | النوع: $typeText'),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F4C81),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddDriverModal(context),
      ),
    );
  }
}
