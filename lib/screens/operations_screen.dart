import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/operation_model.dart';
import '../services/accounting_service.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  final supabase = Supabase.instance.client;
  List<OperationModel> operations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchOperations();
  }

  Future<void> fetchOperations() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('operations')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        operations =
            (response as List).map((e) => OperationModel.fromJson(e)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _showAddOperationModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddOperationSheet(onSaved: fetchOperations),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : operations.isEmpty
              ? const Center(
                  child: Text('لا توجد عمليات مسجلة حالياً',
                      style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: fetchOperations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: operations.length,
                    itemBuilder: (context, index) {
                      final op = operations[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long,
                              color: Color(0xFF0F4C81)),
                          title: Text(
                              'إيراد: ${op.revenue.toStringAsFixed(2)} ر.س',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${op.equipmentName.isEmpty ? "بدون معدة" : op.equipmentName} • ${op.driverName.isEmpty ? "بدون سائق" : op.driverName}\n'
                              'صافي المالك: ${op.ownerNet.toStringAsFixed(2)} ر.س | صافي السائق: ${op.driverNet.toStringAsFixed(2)} ر.س'),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F4C81),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddOperationModal(context),
      ),
    );
  }
}

// ============================================================
// نافذة إضافة عملية جديدة
// ============================================================
class _AddOperationSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddOperationSheet({required this.onSaved});

  @override
  State<_AddOperationSheet> createState() => _AddOperationSheetState();
}

class _AddOperationSheetState extends State<_AddOperationSheet> {
  final supabase = Supabase.instance.client;
  bool _isLoadingLists = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _equipmentList = [];
  List<Map<String, dynamic>> _driversList = [];
  List<Map<String, dynamic>> _projectsList = [];

  Map<String, dynamic>? _selectedEquipment;
  Map<String, dynamic>? _selectedDriver;
  Map<String, dynamic>? _selectedProject;

  final _revenueController = TextEditingController(text: '0');
  final _cityController = TextEditingController(text: '0');
  final _repairController = TextEditingController(text: '0');
  final _otherController = TextEditingController(text: '0');
  final _sharedController = TextEditingController(text: '0');
  final _clientController = TextEditingController();

  SharedExpenseHandling _handling = SharedExpenseHandling.addToOwner;

  @override
  void initState() {
    super.initState();
    _fetchLists();
    for (final c in [
      _revenueController,
      _cityController,
      _repairController,
      _otherController,
      _sharedController,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  Future<void> _fetchLists() async {
    try {
      final eq = await supabase.from('equipment').select();
      final dr = await supabase.from('drivers').select();
      final pr = await supabase.from('projects').select();
      if (mounted) {
        setState(() {
          _equipmentList = List<Map<String, dynamic>>.from(eq);
          _driversList = List<Map<String, dynamic>>.from(dr);
          _projectsList = List<Map<String, dynamic>>.from(pr);
          _isLoadingLists = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLists = false);
    }
  }

  double _parse(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  /// نوع عقد السائق المختار حالياً ونسبته
  String get _contractType =>
      _selectedDriver?['contract_type']?.toString() ?? 'ratio';
  double get _ownerRatio =>
      (_selectedDriver?['owner_ratio'] as num?)?.toDouble() ?? 2.0;
  double get _driverRatio =>
      (_selectedDriver?['driver_ratio'] as num?)?.toDouble() ?? 1.0;

  AccountingResult? get _preview {
    if (_selectedDriver == null) return null;
    return AccountingService.calculate(AccountingInput(
      revenue: _parse(_revenueController),
      cityExpense: _parse(_cityController),
      repairExpense: _parse(_repairController),
      otherExpense: _parse(_otherController),
      sharedExpense: _parse(_sharedController),
      contractType: _contractType,
      ownerRatio: _ownerRatio,
      driverRatio: _driverRatio,
      sharedExpenseHandling: _handling,
    ));
  }

  Future<void> _save() async {
    if (_selectedEquipment == null || _selectedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المعدة والسائق')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final op = OperationModel.calculate(
        date: DateTime.now().toIso8601String().substring(0, 10),
        equipmentId: _selectedEquipment!['id'].toString(),
        equipmentName: _selectedEquipment!['name']?.toString() ?? '',
        driverId: _selectedDriver!['id'].toString(),
        driverName: _selectedDriver!['name']?.toString() ?? '',
        projectId: _selectedProject?['id']?.toString() ?? '',
        projectName: _selectedProject?['name']?.toString() ?? '',
        clientName: _clientController.text.trim(),
        revenue: _parse(_revenueController),
        cityExpense: _parse(_cityController),
        repairExpense: _parse(_repairController),
        otherExpense: _parse(_otherController),
        sharedExpense: _parse(_sharedController),
        contractType: _contractType,
        ownerRatio: _ownerRatio,
        driverRatio: _driverRatio,
        sharedExpenseHandling: _handling,
      );

      await supabase.from('operations').insert(op.toJson());

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ العملية وحساب الصافي بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ أثناء الحفظ: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLists) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final preview = _preview;

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
            const Text('إضافة عملية تشغيلية جديدة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // ---- اختيار المعدة ----
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedEquipment,
              decoration: const InputDecoration(
                labelText: 'المعدة *',
                border: OutlineInputBorder(),
              ),
              items: _equipmentList.map((eq) {
                return DropdownMenuItem(
                    value: eq, child: Text(eq['name']?.toString() ?? ''));
              }).toList(),
              onChanged: (val) => setState(() => _selectedEquipment = val),
            ),
            const SizedBox(height: 12),

            // ---- اختيار السائق ----
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedDriver,
              decoration: const InputDecoration(
                labelText: 'السائق *',
                border: OutlineInputBorder(),
              ),
              items: _driversList.map((dr) {
                final isFixed = dr['contract_type'] == 'fixed';
                return DropdownMenuItem(
                  value: dr,
                  child: Text(
                      '${dr['name'] ?? ''} ${isFixed ? "(راتب ثابت)" : "(نسبة)"}'),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedDriver = val),
            ),
            const SizedBox(height: 12),

            // ---- اختيار المشروع (اختياري) ----
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedProject,
              decoration: const InputDecoration(
                labelText: 'المشروع (اختياري)',
                border: OutlineInputBorder(),
              ),
              items: _projectsList.map((pr) {
                return DropdownMenuItem(
                    value: pr, child: Text(pr['name']?.toString() ?? ''));
              }).toList(),
              onChanged: (val) => setState(() => _selectedProject = val),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _clientController,
              decoration: const InputDecoration(
                labelText: 'اسم العميل (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),

            TextField(
              controller: _revenueController,
              decoration: const InputDecoration(
                  labelText: 'الإيراد (ر.س)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                  labelText: 'مصاريف المدينة (على المالك فقط)',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _repairController,
              decoration: const InputDecoration(
                  labelText: 'مصاريف الإصلاحات (على المالك فقط)',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _otherController,
              decoration: const InputDecoration(
                  labelText: 'مصاريف أخرى (على المالك فقط)',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sharedController,
              decoration: const InputDecoration(
                  labelText: 'المصاريف المشتركة (ديزل/زيوت)',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),

            // ---- خيار معالجة المصروف المشترك (يظهر فقط لعقد النسبة) ----
            if (_contractType == 'ratio' && _parse(_sharedController) > 0) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<SharedExpenseHandling>(
                value: _handling,
                decoration: const InputDecoration(
                  labelText: 'نصيب السائق من المصروف المشترك',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: SharedExpenseHandling.addToOwner,
                    child: Text('يُخصم من السائق ويرجع للمالك (المالك دفعها)'),
                  ),
                  DropdownMenuItem(
                    value: SharedExpenseHandling.operatingExpense,
                    child: Text('يُخصم من السائق ولا يرجع (مصروفة فعلاً)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _handling = val);
                },
              ),
            ],

            const SizedBox(height: 20),

            // ---- معاينة الحساب الفورية ----
            if (preview != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F4C81).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF0F4C81).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('معاينة الحساب',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    _previewRow('صافي السائق',
                        AccountingService.toNumber(preview.driverNet)),
                    _previewRow('صافي المالك',
                        AccountingService.toNumber(preview.ownerNet)),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C81),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('حفظ العملية وحساب الصافي'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _previewRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black87)),
          Text('${value.toStringAsFixed(2)} ر.س',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
        ],
      ),
    );
  }
}
