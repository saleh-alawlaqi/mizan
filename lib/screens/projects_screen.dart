import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> projectsList = [];
  Map<String, double> _receivedByProject = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProjects();
  }

  Future<void> fetchProjects() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('projects')
          .select()
          .order('created_at', ascending: false);
      final payments = await supabase.from('project_payments').select();

      final received = <String, double>{};
      for (final p in payments) {
        final pid = p['project_id'].toString();
        final amount = (p['amount'] as num?)?.toDouble() ?? 0;
        received[pid] = (received[pid] ?? 0) + amount;
      }

      setState(() {
        projectsList = List<Map<String, dynamic>>.from(response);
        _receivedByProject = received;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteProject(Map<String, dynamic> project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المشروع'),
        content: Text('هل أنت متأكد من حذف "${project['name']}"؟'),
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
      await supabase.from('projects').delete().eq('id', project['id']);
      fetchProjects();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('تعذّر الحذف: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showProjectModal(BuildContext context,
      {Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final locationController =
        TextEditingController(text: existing?['location'] ?? '');
    final contractValueController = TextEditingController(
        text: (existing?['contract_value'] ?? '').toString());

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
                  Text(isEdit ? 'تعديل بيانات المشروع' : 'إضافة مشروع جديد',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                          labelText: 'اسم المشروع',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                          labelText: 'موقع المشروع / المدينة',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                      controller: contractValueController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'قيمة العقد الإجمالية (ر.س)',
                          border: OutlineInputBorder(),
                          helperText: 'اتركه فاضي لو ما فيه عقد بمبلغ محدد')),
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
                                'location': locationController.text.trim(),
                                'contract_value': contractValueController.text
                                        .trim()
                                        .isEmpty
                                    ? null
                                    : double.tryParse(
                                        contractValueController.text.trim()),
                              };
                              if (isEdit) {
                                await supabase
                                    .from('projects')
                                    .update(data)
                                    .eq('id', existing['id']);
                              } else {
                                await supabase.from('projects').insert(data);
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                                fetchProjects();
                              }
                            } catch (e) {
                              setModalState(() => isSaving = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('خطأ: $e'),
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
                        : Text(isEdit ? 'حفظ التعديلات' : 'حفظ المشروع'),
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

  void _showPaymentsSheet(BuildContext context, Map<String, dynamic> project) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProjectPaymentsSheet(
        project: project,
        onChanged: fetchProjects,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : projectsList.isEmpty
              ? const Center(
                  child: Text('لا توجد مشاريع مسجلة حالياً',
                      style: TextStyle(color: AppTheme.textMuted)))
              : RefreshIndicator(
                  onRefresh: fetchProjects,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: projectsList.length,
                    itemBuilder: (context, index) {
                      final item = projectsList[index];
                      final contractValue =
                          (item['contract_value'] as num?)?.toDouble();
                      final received =
                          _receivedByProject[item['id'].toString()] ?? 0;
                      final remaining = contractValue != null
                          ? contractValue - received
                          : null;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(item['name'] ?? 'بدون اسم',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        size: 18, color: AppTheme.primary),
                                    onPressed: () => _showProjectModal(context,
                                        existing: item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: Colors.red),
                                    onPressed: () => _deleteProject(item),
                                  ),
                                ],
                              ),
                              Text('الموقع: ${item['location'] ?? 'غير متوفر'}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.textMuted)),
                              if (contractValue != null) ...[
                                const SizedBox(height: 10),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _statColumn('قيمة العقد', contractValue),
                                    _statColumn('المستلم', received,
                                        color: AppTheme.success),
                                    _statColumn('المتبقي', remaining ?? 0,
                                        color: AppTheme.warning),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _showPaymentsSheet(context, item),
                                  icon:
                                      const Icon(Icons.receipt_long, size: 16),
                                  label: const Text('المستخلصات والدفعات'),
                                ),
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
        onPressed: () => _showProjectModal(context),
      ),
    );
  }

  Widget _statColumn(String label, double value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        Text('${value.toStringAsFixed(0)} ر.س',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color ?? AppTheme.textPrimary)),
      ],
    );
  }
}

// ============================================================
// نافذة المستخلصات: سجل الدفعات + إضافة مستخلص جديد
// ============================================================
class _ProjectPaymentsSheet extends StatefulWidget {
  final Map<String, dynamic> project;
  final VoidCallback onChanged;

  const _ProjectPaymentsSheet({required this.project, required this.onChanged});

  @override
  State<_ProjectPaymentsSheet> createState() => _ProjectPaymentsSheetState();
}

class _ProjectPaymentsSheetState extends State<_ProjectPaymentsSheet> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('project_payments')
          .select()
          .eq('project_id', widget.project['id'].toString())
          .order('created_at', ascending: false);
      setState(() {
        _payments = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  double get _total => _payments.fold(
      0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));

  Future<void> _addPayment() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;
    setState(() => _isSaving = true);
    try {
      await supabase.from('project_payments').insert({
        'project_id': widget.project['id'].toString(),
        'amount': amount,
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'note': _noteController.text.trim(),
      });
      _amountController.clear();
      _noteController.clear();
      await _fetch();
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deletePayment(Map<String, dynamic> payment) async {
    await supabase.from('project_payments').delete().eq('id', payment['id']);
    await _fetch();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final contractValue =
        (widget.project['contract_value'] as num?)?.toDouble();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('مستخلصات: ${widget.project['name']}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (contractValue != null)
                  Text(
                    'إجمالي المستلم: ${_total.toStringAsFixed(0)} ر.س من ${contractValue.toStringAsFixed(0)} ر.س (المتبقي ${(contractValue - _total).toStringAsFixed(0)} ر.س)',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'مبلغ المستخلص',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                            labelText: 'ملاحظة (اختياري)',
                            border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _addPayment,
                  icon: const Icon(Icons.add),
                  label: Text(_isSaving ? 'جارٍ الحفظ...' : 'تسجيل المستخلص'),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const Text('سجل المستخلصات',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text('لا توجد مستخلصات مسجلة بعد',
                            style: TextStyle(color: AppTheme.textMuted))),
                  )
                else
                  ..._payments.map((p) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.receipt,
                              color: AppTheme.success),
                          title: Text(
                              '${(p['amount'] as num).toStringAsFixed(0)} ر.س'),
                          subtitle: Text(
                              '${p['date'] ?? ''}${(p['note']?.toString().isNotEmpty ?? false) ? ' - ${p['note']}' : ''}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                            onPressed: () => _deletePayment(p),
                          ),
                        ),
                      )),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
