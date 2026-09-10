import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OwnersScreen extends StatefulWidget {
  const OwnersScreen({super.key});

  @override
  State<OwnersScreen> createState() => _OwnersScreenState();
}

class _OwnersScreenState extends State<OwnersScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> ownersList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchOwners();
  }

  Future<void> fetchOwners() async {
    try {
      final response = await supabase
          .from('owners')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        ownersList = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _showAddOwnerModal(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
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
              const Text('إضافة مالك جديد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'اسم المالك', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                      labelText: 'رقم الجوال', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4C81),
                    foregroundColor: Colors.white),
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    try {
                      await supabase.from('owners').insert({
                        'name': nameController.text,
                        'phone': phoneController.text,
                      });
                      Navigator.pop(context);
                      fetchOwners();
                    } catch (e) {
                      // Handle error
                    }
                  }
                },
                child: const Text('حفظ المالك'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ownersList.isEmpty
              ? const Center(
                  child: Text('لا توجد ملاك مسجلين حالياً',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ownersList.length,
                  itemBuilder: (context, index) {
                    final item = ownersList[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.person_outline,
                            color: Color(0xFF0F4C81)),
                        title: Text(item['name'] ?? 'بدون اسم',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle:
                            Text('الجوال: ${item['phone'] ?? 'غير متوفر'}'),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F4C81),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddOwnerModal(context),
      ),
    );
  }
}
