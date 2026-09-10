import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

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
    String selectedStatus = existing?['status'] ?? 'active';

    List<dynamic> driversList = [];
    try {
      driversList = await supabase.from('drivers').select();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : equipmentList.isEmpty
              ? const Center(
                  child: Text('لا توجد معدات مسجلة حالياً',
                      style: TextStyle(color: AppTheme.textMuted)))
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

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.local_shipping,
                              color: AppTheme.primary),
                          title: Text(item['name'] ?? 'بدون اسم',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'رقم اللوحة: ${item['plate_number'] ?? 'غير متوفر'} | الموديل: ${item['model'] ?? 'غير متوفر'}\n'
                            'السائق: ${item['current_driver'] ?? 'بدون سائق'}',
                          ),
                          isThreeLine: true,
                          onTap: () =>
                              _showEquipmentModal(context, existing: item),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(statusLabel,
                                    style: TextStyle(
                                        fontSize: 11, color: statusColor)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 20),
                                onPressed: () => _deleteEquipment(item),
                              ),
                            ],
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
