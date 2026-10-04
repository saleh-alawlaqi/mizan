import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class TeamService {
  static final supabase = Supabase.instance.client;

  /// يُستدعى مرة عند كل دخول: يبحث عن دعوات معلّقة بإيميل المستخدم الحالي
  /// ويربطها تلقائياً بحسابه (بدون تدخل يدوي)
  static Future<void> claimPendingInvites() async {
    final email = supabase.auth.currentUser?.email;
    final uid = supabase.auth.currentUser?.id;
    if (email == null || uid == null) return;

    try {
      final pending = await supabase
          .from('team_members')
          .select()
          .eq('invited_email', email)
          .isFilter('member_user_id', null);

      for (final invite in pending) {
        await supabase.from('team_members').update(
            {'member_user_id': uid, 'status': 'active'}).eq('id', invite['id']);
      }
    } catch (_) {
      // تجاهل بهدوء - يحدث فقط إذا فيه دعوة فعلاً
    }
  }
}

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('team_members')
          .select()
          .eq('owner_user_id', supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);
      setState(() {
        _members = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة العضو'),
        content: Text('إزالة "${member['invited_email']}" من الفريق؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إزالة', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await supabase.from('team_members').delete().eq('id', member['id']);
    _fetch();
  }

  void _showInviteModal() {
    final emailController = TextEditingController();
    String role = 'viewer';

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
                  const Text('دعوة مستخدم جديد',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    'المستخدم لازم يسجّل حساب بنفس هذا البريد من شاشة الدخول، وبيرتبط تلقائياً بحسابك بأول دخول له.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(
                        labelText: 'الصلاحية', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(
                          value: 'admin', child: Text('مدير (صلاحيات كاملة)')),
                      DropdownMenuItem(
                          value: 'editor', child: Text('محرر (إضافة وتعديل)')),
                      DropdownMenuItem(
                          value: 'viewer', child: Text('مشاهد (عرض فقط)')),
                    ],
                    onChanged: (val) => setModalState(() => role = val!),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (!emailController.text.contains('@')) return;
                            setModalState(() => isSaving = true);
                            try {
                              await supabase.from('team_members').insert({
                                'owner_user_id': supabase.auth.currentUser!.id,
                                'invited_email': emailController.text.trim(),
                                'role': role,
                                'status': 'pending',
                              });
                              if (context.mounted) {
                                Navigator.pop(context);
                                _fetch();
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
                        : const Text('إرسال الدعوة'),
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

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'مدير';
      case 'editor':
        return 'محرر';
      default:
        return 'مشاهد';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('صلاحيات الفريق')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? const Center(
                  child: Text('لم تدعُ أي مستخدم بعد',
                      style: TextStyle(color: AppTheme.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final m = _members[index];
                    final isActive = m['status'] == 'active';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive
                              ? AppTheme.successLight
                              : AppTheme.warningLight,
                          child: Icon(Icons.person,
                              color: isActive
                                  ? AppTheme.success
                                  : AppTheme.warning),
                        ),
                        title: Text(m['invited_email'] ?? ''),
                        subtitle: Text(
                            '${_roleLabel(m['role'])} • ${isActive ? "منضم" : "بانتظار الانضمام"}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _removeMember(m),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.person_add),
        onPressed: _showInviteModal,
      ),
    );
  }
}
