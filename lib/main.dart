import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/subscription_gate.dart';
import 'screens/admin_panel_screen.dart';

// الشاشات الأساسية
import 'screens/dashboard_screen.dart';
import 'screens/equipment_screen.dart';
import 'screens/drivers_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/owners_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/operations_screen.dart';
import 'screens/reports_screen.dart';

// شاشات إضافية
import 'screens/settings_screen.dart';
import 'screens/account_statement_screen.dart';
import 'screens/users_screen.dart';
import 'screens/team_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/salary_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fuulejyoclhbwdmdgafo.supabase.co',
    anonKey: 'sb_publishable_rsmKB99ZCmEfmB-jwQrWgg_FkdVNi2r',
  );

  runApp(const MizanApp());
}

final supabase = Supabase.instance.client;

class MizanApp extends StatelessWidget {
  const MizanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ميزان - إدارة المعدات الثقيلة',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: AppTheme.themeData(),
      home: const AuthGate(),
    );
  }
}

/// بوابة الدخول: تسجيل الدخول -> التحقق من الاشتراك -> الشاشة الرئيسية
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastCheckedUserId;
  SubscriptionStatus? _subscriptionStatus;
  bool _isCheckingSubscription = false;

  Future<void> _claimInvitesIfNeeded(String userId) async {
    try {
      final email = supabase.auth.currentUser?.email;
      if (email == null) return;
      final pending = await supabase
          .from('team_members')
          .select()
          .eq('invited_email', email)
          .isFilter('member_user_id', null);
      for (final invite in pending) {
        await supabase
            .from('team_members')
            .update({'member_user_id': userId, 'status': 'active'}).eq(
                'id', invite['id']);
      }
    } catch (_) {}
  }

  Future<void> _runChecks(String userId) async {
    if (_isCheckingSubscription) return;
    _isCheckingSubscription = true;
    await _claimInvitesIfNeeded(userId);
    final status = await SubscriptionService.checkAndEnsureSubscription();
    _lastCheckedUserId = userId;
    _isCheckingSubscription = false;
    if (mounted) setState(() => _subscriptionStatus = status);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        if (session == null) {
          _lastCheckedUserId = null;
          _subscriptionStatus = null;
          return const LoginScreen();
        }

        if (_lastCheckedUserId != session.user.id) {
          // مستخدم جديد أو أول تحميل - شغّل الفحص
          Future.microtask(() => _runChecks(session.user.id));
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (_subscriptionStatus == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (_subscriptionStatus == SubscriptionStatus.active) {
          return const MainLayout();
        }

        return SubscriptionBlockedScreen(status: _subscriptionStatus!);
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    AdminService.isCurrentUserAdmin().then((val) {
      if (mounted) setState(() => _isAdmin = val);
    });
  }

  final List<Widget> _screens = [
    const DashboardScreen(),
    const EquipmentScreen(),
    const DriversScreen(),
    const ClientsScreen(),
    const OwnersScreen(),
    const ProjectsScreen(),
    const OperationsScreen(),
    const ReportsScreen(),
  ];

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await supabase.auth.signOut();
    }
  }

  void _go(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = supabase.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.balance, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('ميزان',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ],
        ),
        centerTitle: false,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.primary),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Text('م',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary)),
              ),
              accountName: const Text('مدير النظام',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(userEmail),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(0, 'لوحة التحكم', Icons.dashboard_outlined),
                  _drawerItem(1, 'المعدات', Icons.local_shipping_outlined),
                  _drawerItem(2, 'السائقون', Icons.badge_outlined),
                  _drawerItem(3, 'العملاء', Icons.people_outline),
                  _drawerItem(4, 'الملاك', Icons.person_outline),
                  _drawerItem(5, 'المشاريع', Icons.folder_open_outlined),
                  _drawerItem(
                      6, 'العمليات اليومية', Icons.receipt_long_outlined),
                  _drawerItem(7, 'التقارير', Icons.bar_chart),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined,
                        color: AppTheme.primary),
                    title: const Text('محفظة المالك'),
                    onTap: () => _go(const WalletScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.payments_outlined,
                        color: AppTheme.primary),
                    title: const Text('رواتب السائقين'),
                    onTap: () => _go(const SalaryScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet,
                        color: AppTheme.primary),
                    title: const Text('كشف حساب الملاك والسائقين'),
                    onTap: () => _go(const AccountStatementScreen()),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.people_alt_outlined,
                        color: AppTheme.primary),
                    title: const Text('المستخدمون'),
                    onTap: () => _go(const UsersScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined,
                        color: AppTheme.primary),
                    title: const Text('صلاحيات الفريق'),
                    onTap: () => _go(const TeamScreen()),
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.settings, color: AppTheme.primary),
                    title: const Text('الإعدادات'),
                    onTap: () => _go(const SettingsScreen()),
                  ),
                  if (_isAdmin) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.shield_outlined,
                          color: Colors.deepPurple),
                      title: const Text('لوحة إدارة الاشتراكات',
                          style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold)),
                      onTap: () => _go(const AdminPanelScreen()),
                    ),
                  ],
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('تسجيل الخروج',
                        style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      _signOut();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _screens[_currentIndex],
    );
  }

  Widget _drawerItem(int index, String title, IconData icon) {
    bool isSelected = _currentIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading:
            Icon(icon, color: isSelected ? AppTheme.primary : Colors.grey[700]),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.primary : Colors.black87,
          ),
        ),
        selected: isSelected,
        onTap: () {
          setState(() => _currentIndex = index);
          Navigator.pop(context);
        },
      ),
    );
  }
}
