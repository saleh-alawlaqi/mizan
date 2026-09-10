import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> clientsList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchClients();
  }

  Future<void> fetchClients() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('clients')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        clientsList = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteClient(Map<String, dynamic> client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العميل'),
        content: Text('هل أنت متأكد من حذف "${client['name']}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await supabase.from('clients').delete().eq('id', client['id']);
      fetchClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف العميل'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر الحذف: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showClientModal(BuildContext context, {Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final phoneController = TextEditingController(text: existing?['phone'] ?? '');

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(isEdit ? 'تعديل بيانات العميل' : 'إضافة عميل جديد',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                          labelText: 'اسم العميل / الشركة', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                          labelText: 'رقم الجوال', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (nameController.text.trim().isEmpty) return;
                            setModalState(() => isSaving = true);
                            try {
                              final data = {
                                'name': nameController.text.trim(),
                                'phone': phoneController.text.trim(),
                              };
                              if (isEdit) {
                                await supabase.from('clients').update(data).eq('id', existing['id']);
                              } else {
                                await supabase.from('clients').insert(data);
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                                fetchClients();
                              }
                            } catch (e) {
                              setModalState(() => isSaving = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isEdit ? 'حفظ التعديلات' : 'حفظ العميل'),
                  ),
                  const SizedBox(height: 20),
                ],
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
          : clientsList.isEmpty
              ? const Center(
                  child: Text('لا توجد عملاء مسجلين حالياً',
                      style: TextStyle(color: AppTheme.textMuted)))
              : RefreshIndicator(
                  onRefresh: fetchClients,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: clientsList.length,
                    itemBuilder: (context, index) {
                      final item = clientsList[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.people_outline, color: AppTheme.primary),
                          title: Text(item['name'] ?? 'بدون اسم',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('الجوال: ${item['phone'] ?? 'غير متوفر'}'),
                          onTap: () => _showClientModal(context, existing: item),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteClient(item),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showClientModal(context),
      ),
    );
  }
}
