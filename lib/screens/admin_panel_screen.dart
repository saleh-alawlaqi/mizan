import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

/// يتحقق هل المستخدم الحالي مدير نظام (يُستدعى من main.dart لإظهار/إخفاء الرابط)
class AdminService {
  static final supabase = Supabase.instance.client;

  static Future<bool> isCurrentUserAdmin() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final res = await supabase
          .from('super_admins')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      return res != null;
    } catch (e) {
      return false;
    }
  }
}

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _subscriptions = [];
  String _filter = 'all'; // all | pending | active | expired | suspended

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('subscriptions')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _subscriptions = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e (تأكد أنك مضاف كـ super_admin)')),
        );
      }
    }
  }

  Future<void> _setStatus(Map<String, dynamic> sub, String status,
      {DateTime? expiresAt, bool clearExpiry = false}) async {
    try {
      final data = <String, dynamic>{'status': status};
      if (status == 'active') {
        data['activated_at'] = DateTime.now().toIso8601String();
        if (clearExpiry) {
          data['expires_at'] = null;
        } else if (expiresAt != null) {
          data['expires_at'] = expiresAt.toIso8601String();
        }
      }
      await supabase.from('subscriptions').update(data).eq('id', sub['id']);
      _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث الحالة إلى: ${_statusLabel(status)}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// يفتح نافذة اختيار: تفعيل بتاريخ انتهاء محدد، أو تفعيل دائم بدون انتهاء
  Future<void> _showActivateDialog(Map<String, dynamic> sub) async {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 365));

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('تفعيل اشتراك: ${sub['user_email'] ?? ''}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اختر مدة الاشتراك:'),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event, color: AppTheme.primary),
                    title: Text(
                        'حتى تاريخ: ${selectedDate.toIso8601String().substring(0, 10)}'),
                    trailing: const Icon(Icons.edit, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setDialogState(() => selectedDate =
                              DateTime.now().add(const Duration(days: 30))),
                          child: const Text('شهر'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setDialogState(() => selectedDate =
                              DateTime.now().add(const Duration(days: 90))),
                          child: const Text('3 أشهر'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setDialogState(() => selectedDate =
                              DateTime.now().add(const Duration(days: 365))),
                          child: const Text('سنة'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _setStatus(sub, 'active', clearExpiry: true);
                  },
                  child: const Text('صلاحية دائمة (بدون انتهاء)',
                      style: TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _setStatus(sub, 'active', expiresAt: selectedDate);
                  },
                  child: const Text('تفعيل بهذا التاريخ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editExpiry(Map<String, dynamic> sub) async {
    DateTime initial = sub['expires_at'] != null
        ? DateTime.tryParse(sub['expires_at'].toString()) ?? DateTime.now()
        : DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    await supabase
        .from('subscriptions')
        .update({'expires_at': picked.toIso8601String()}).eq('id', sub['id']);
    _fetch();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'مفعّل';
      case 'pending':
        return 'قيد الانتظار';
      case 'expired':
        return 'منتهي';
      case 'suspended':
        return 'موقوف';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.success;
      case 'pending':
        return AppTheme.warning;
      case 'expired':
      case 'suspended':
        return AppTheme.destructive;
      default:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _subscriptions
        : _subscriptions.where((s) => s['status'] == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة إدارة الاشتراكات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('الكل', 'all'),
                        _filterChip('قيد الانتظار', 'pending'),
                        _filterChip('مفعّل', 'active'),
                        _filterChip('منتهي', 'expired'),
                        _filterChip('موقوف', 'suspended'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('لا توجد اشتراكات مطابقة',
                              style: TextStyle(color: AppTheme.textMuted)))
                      : RefreshIndicator(
                          onRefresh: _fetch,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final sub = filtered[index];
                              final status =
                                  sub['status']?.toString() ?? 'pending';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              sub['user_email']?.toString() ??
                                                  '',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _statusColor(status)
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(_statusLabel(status),
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        _statusColor(status))),
                                          ),
                                        ],
                                      ),
                                      if (sub['phone'] != null &&
                                          sub['phone'].toString().isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text('جوال: ${sub['phone']}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textMuted)),
                                        ),
                                      if (sub['notes'] != null &&
                                          sub['notes'].toString().isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text('ملاحظة: ${sub['notes']}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textMuted)),
                                        ),
                                      if (sub['expires_at'] != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: GestureDetector(
                                            onTap: () => _editExpiry(sub),
                                            child: Row(
                                              children: [
                                                Text(
                                                  'ينتهي: ${sub['expires_at'].toString().substring(0, 10)}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppTheme.textMuted),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.edit,
                                                    size: 12,
                                                    color: AppTheme.primary),
                                              ],
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 10),
                                      if (status == 'active' &&
                                          sub['expires_at'] == null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.deepPurple
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text('صلاحية دائمة ∞',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.deepPurple,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _actionButton(
                                              status == 'active'
                                                  ? 'تجديد/تعديل المدة'
                                                  : 'تفعيل',
                                              AppTheme.success,
                                              () => _showActivateDialog(sub)),
                                          if (status != 'suspended')
                                            _actionButton(
                                                'إيقاف',
                                                AppTheme.warning,
                                                () => _setStatus(
                                                    sub, 'suspended')),
                                          if (status != 'expired')
                                            _actionButton(
                                                'تعيين كمنتهي',
                                                AppTheme.destructive,
                                                () =>
                                                    _setStatus(sub, 'expired')),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: AppTheme.primaryLight,
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
          foregroundColor: color, side: BorderSide(color: color)),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
