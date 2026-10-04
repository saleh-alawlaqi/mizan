import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/pdf_helper.dart';
import 'package:pdf/widgets.dart' as pw;

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
    setState(() => isLoading = true);
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
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteDriver(Map<String, dynamic> driver) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف السائق'),
        content: Text('هل أنت متأكد من حذف "${driver['name']}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await supabase.from('drivers').delete().eq('id', driver['id']);
      fetchDrivers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حذف السائق'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('تعذّر الحذف: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDriverModal(BuildContext context,
      {Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final phoneController =
        TextEditingController(text: existing?['phone'] ?? '');
    String contractType = existing?['contract_type'] ?? 'ratio';
    final salaryController = TextEditingController(
        text: (existing?['monthly_salary'] ?? 0).toString());
    final ownerRatioController =
        TextEditingController(text: (existing?['owner_ratio'] ?? 2).toString());
    final driverRatioController = TextEditingController(
        text: (existing?['driver_ratio'] ?? 1).toString());

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(isEdit ? 'تعديل بيانات السائق' : 'إضافة سائق جديد',
                        style: const TextStyle(
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
                          labelText: 'نوع العقد', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(
                            value: 'ratio', child: Text('نسبة مئوية')),
                        DropdownMenuItem(
                            value: 'fixed', child: Text('راتب شهري ثابت')),
                        DropdownMenuItem(
                            value: 'daily', child: Text('سائق يوميات (مؤقت)')),
                      ],
                      onChanged: (val) =>
                          setModalState(() => contractType = val!),
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
                    if (contractType == 'ratio') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ownerRatioController,
                              decoration: const InputDecoration(
                                  labelText: 'نسبة المالك',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: driverRatioController,
                              decoration: const InputDecoration(
                                  labelText: 'نسبة السائق',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                            'مثال: مالك 2 وسائق 1 يعني السائق ياخذ 1/3 من كل عملية',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textMuted)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (nameController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('يرجى إدخال اسم السائق')),
                                );
                                return;
                              }
                              setModalState(() => isSaving = true);
                              try {
                                final data = {
                                  'name': nameController.text.trim(),
                                  'phone': phoneController.text.trim().isEmpty
                                      ? null
                                      : phoneController.text.trim(),
                                  'contract_type': contractType,
                                  'monthly_salary': contractType == 'fixed'
                                      ? (double.tryParse(
                                              salaryController.text) ??
                                          0)
                                      : 0,
                                  'owner_ratio': contractType == 'ratio'
                                      ? (double.tryParse(
                                              ownerRatioController.text) ??
                                          2)
                                      : 2,
                                  'driver_ratio': contractType == 'ratio'
                                      ? (double.tryParse(
                                              driverRatioController.text) ??
                                          1)
                                      : 1,
                                };
                                if (isEdit) {
                                  await supabase
                                      .from('drivers')
                                      .update(data)
                                      .eq('id', existing['id']);
                                } else {
                                  await supabase.from('drivers').insert(data);
                                }
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  fetchDrivers();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEdit
                                          ? 'تم تحديث بيانات السائق'
                                          : 'تم إضافة السائق بنجاح'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('خطأ أثناء الحفظ: $e'),
                                        backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'حفظ التعديلات' : 'حفظ السائق'),
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

  Future<void> _exportPdf() async {
    await PdfHelper.buildAndPrint(
      title: 'تقرير السائقين',
      fileName: 'تقرير_السائقين.pdf',
      content: (font, fontBold) => [
        PdfHelper.table(
          font: font,
          fontBold: fontBold,
          headers: ['الاسم', 'الجوال', 'نوع العقد', 'التفاصيل'],
          rows: driversList.map((item) {
            final cType = item['contract_type'];
            String details =
                'نسبة (${item['owner_ratio'] ?? 2}:${item['driver_ratio'] ?? 1})';
            String typeLabel = 'نسبة';
            if (cType == 'fixed') {
              typeLabel = 'راتب ثابت';
              details = '${item['monthly_salary'] ?? 0} ر.س شهرياً';
            } else if (cType == 'daily') {
              typeLabel = 'يوميات';
              details = 'سائق مؤقت';
            }
            return [
              item['name']?.toString() ?? '',
              item['phone']?.toString() ?? '-',
              typeLabel,
              details,
            ];
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('السائقون'),
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
          : driversList.isEmpty
              ? const EmptyState(
                  icon: Icons.badge_outlined,
                  message:
                      'لا توجد سائقين مسجلين حالياً\nاضغط + لإضافة أول سائق')
              : RefreshIndicator(
                  onRefresh: fetchDrivers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: driversList.length,
                    itemBuilder: (context, index) {
                      final item = driversList[index];
                      final cType = item['contract_type'];
                      String typeText =
                          'نسبة (${item['owner_ratio'] ?? 2}:${item['driver_ratio'] ?? 1})';
                      if (cType == 'fixed') {
                        typeText = "راتب شهري (${item['monthly_salary']} ر.س)";
                      } else if (cType == 'daily') {
                        typeText = "سائق يوميات";
                      }

                      final isFixed = cType == 'fixed';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              _showDriverModal(context, existing: item),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: isFixed
                                        ? AppTheme.purpleLight
                                        : AppTheme.primaryLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.badge,
                                      color: isFixed
                                          ? AppTheme.purple
                                          : AppTheme.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                                item['name'] ?? 'بدون اسم',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14)),
                                          ),
                                          StatusBadge(
                                            label:
                                                isFixed ? 'راتب ثابت' : 'نسبة',
                                            color: isFixed
                                                ? AppTheme.purple
                                                : AppTheme.primary,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                          '${item['phone'] ?? 'بدون جوال'}  •  $typeText',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textMuted)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppTheme.destructive, size: 20),
                                  onPressed: () => _deleteDriver(item),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showDriverModal(context),
      ),
    );
  }
}
