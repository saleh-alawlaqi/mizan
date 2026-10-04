import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/pdf_helper.dart';
import 'package:pdf/widgets.dart' as pw;

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> equipmentList = [];
  bool isLoading = true;

  final List<String> equipmentTypes = [
    'بوكلين',
    'شاحنة',
    'شيول',
    'رافعة',
    'معدات أخرى'
  ];

  @override
  void initState() {
    super.initState();
    fetchEquipment();
  }

  Future<void> fetchEquipment() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('equipment')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        equipmentList = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteEquipment(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المعدة'),
        content: Text(
            'هل أنت متأكد من حذف "${item['name']}"؟\nلن يمكن التراجع عن هذا الإجراء.'),
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
      await supabase.from('equipment').delete().eq('id', item['id']);
      fetchEquipment();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حذف المعدة'), backgroundColor: Colors.green),
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

  void _showEquipmentModal(BuildContext context,
      {Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;

    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final plateController =
        TextEditingController(text: existing?['plate_number'] ?? '');
    final modelController =
        TextEditingController(text: existing?['model'] ?? '');
    final yearController =
        TextEditingController(text: existing?['manufacturing_year'] ?? '');

    String selectedType = existing?['type'] ?? 'بوكلين';
    if (!equipmentTypes.contains(selectedType))
      selectedType = equipmentTypes.first;
    String? selectedDriver = existing?['current_driver'];
    String? selectedOwner = existing?['owner_name'];
    String selectedStatus = existing?['status'] ?? 'active';

    List<dynamic> driversList = [];
    List<dynamic> ownersList = [];
    try {
      driversList = await supabase.from('drivers').select();
      ownersList = await supabase.from('owners').select();
    } catch (_) {}

    if (!context.mounted) return;

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
                    Text(
                      isEdit ? 'تعديل بيانات المعدة' : 'إضافة معدة جديدة',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم المعدة أو نوعها *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: plateController,
                      decoration: const InputDecoration(
                        labelText: 'رقم اللوحة / الكود',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: modelController,
                      decoration: const InputDecoration(
                        labelText: 'الموديل',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: yearController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'سنة الصنع',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'نوع المعدة',
                        border: OutlineInputBorder(),
                      ),
                      items: equipmentTypes
                          .map((type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => selectedType = val!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedDriver,
                      decoration: const InputDecoration(
                        labelText: 'السائق الحالي / سائق يوميات',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                            value: null, child: Text('بدون سائق')),
                        const DropdownMenuItem<String>(
                            value: 'سائق يوميات',
                            child: Text('سائق يوميات (مؤقت)')),
                        ...driversList.map((driver) => DropdownMenuItem<String>(
                              value: driver['name'].toString(),
                              child: Text(driver['name'].toString()),
                            )),
                      ],
                      onChanged: (val) =>
                          setModalState(() => selectedDriver = val),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: ownersList
                              .any((o) => o['name'].toString() == selectedOwner)
                          ? selectedOwner
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'مالك المعدة',
                        border: OutlineInputBorder(),
                        helperText: 'اختر من قائمة الملاك المسجّلين',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                            value: null, child: Text('بدون مالك محدد')),
                        ...ownersList.map((owner) => DropdownMenuItem<String>(
                              value: owner['name'].toString(),
                              child: Text(owner['name'].toString()),
                            )),
                      ],
                      onChanged: (val) =>
                          setModalState(() => selectedOwner = val),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'حالة المعدة',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('تعمل')),
                        DropdownMenuItem(
                            value: 'maintenance', child: Text('في الصيانة')),
                        DropdownMenuItem(value: 'idle', child: Text('متوقفة')),
                      ],
                      onChanged: (val) =>
                          setModalState(() => selectedStatus = val!),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (nameController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('يرجى إدخال اسم المعدة')),
                                );
                                return;
                              }
                              setModalState(() => isSaving = true);
                              final data = {
                                'name': nameController.text.trim(),
                                'type': selectedType,
                                'plate_number':
                                    plateController.text.trim().isEmpty
                                        ? null
                                        : plateController.text.trim(),
                                'model': modelController.text.trim().isEmpty
                                    ? null
                                    : modelController.text.trim(),
                                'manufacturing_year':
                                    yearController.text.trim().isEmpty
                                        ? null
                                        : yearController.text.trim(),
                                'current_driver': selectedDriver,
                                'owner_name': selectedOwner,
                                'status': selectedStatus,
                              };
                              try {
                                if (isEdit) {
                                  await supabase
                                      .from('equipment')
                                      .update(data)
                                      .eq('id', existing['id']);
                                } else {
                                  await supabase.from('equipment').insert(data);
                                }
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  fetchEquipment();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEdit
                                          ? 'تم تحديث بيانات المعدة'
                                          : 'تم إضافة المعدة بنجاح'),
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
                          : Text(isEdit ? 'حفظ التعديلات' : 'حفظ المعدة'),
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
      title: 'تقرير المعدات',
      fileName: 'تقرير_المعدات.pdf',
      content: (font, fontBold) => [
        PdfHelper.table(
          font: font,
          fontBold: fontBold,
          headers: [
            'الاسم',
            'النوع',
            'اللوحة',
            'الموديل',
            'السائق',
            'المالك',
            'الحالة'
          ],
          rows: equipmentList.map((item) {
            final status = item['status'] ?? 'active';
            final statusLabel = status == 'maintenance'
                ? 'صيانة'
                : (status == 'idle' ? 'متوقفة' : 'تعمل');
            return [
              item['name']?.toString() ?? '',
              item['type']?.toString() ?? '',
              item['plate_number']?.toString() ?? '-',
              item['model']?.toString() ?? '-',
              item['current_driver']?.toString() ?? '-',
              item['owner_name']?.toString() ?? '-',
              statusLabel,
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
        title: const Text('المعدات'),
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
          : equipmentList.isEmpty
              ? const EmptyState(
                  icon: Icons.local_shipping_outlined,
                  message: 'لا توجد معدات مسجلة حالياً\nاضغط + لإضافة أول معدة')
              : RefreshIndicator(
                  onRefresh: fetchEquipment,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: equipmentList.length,
                    itemBuilder: (context, index) {
                      final item = equipmentList[index];
                      final status = item['status'] ?? 'active';
                      final statusColor = status == 'maintenance'
                          ? AppTheme.warning
                          : status == 'idle'
                              ? AppTheme.textMuted
                              : AppTheme.success;
                      final statusLabel = status == 'maintenance'
                          ? 'صيانة'
                          : status == 'idle'
                              ? 'متوقفة'
                              : 'تعمل';

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
                              _showEquipmentModal(context, existing: item),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.local_shipping,
                                      color: AppTheme.primary),
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
                                              label: statusLabel,
                                              color: statusColor),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'لوحة: ${item['plate_number'] ?? '—'}  •  موديل: ${item['model'] ?? '—'}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textMuted),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'السائق: ${item['current_driver'] ?? 'بدون سائق'}  •  المالك: ${item['owner_name'] ?? 'غير محدد'}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppTheme.destructive, size: 20),
                                  onPressed: () => _deleteEquipment(item),
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
        onPressed: () => _showEquipmentModal(context),
      ),
    );
  }
}
