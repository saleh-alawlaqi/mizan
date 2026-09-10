import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// استيراد الشاشات الأساسية
import 'screens/dashboard_screen.dart';
import 'screens/equipment_screen.dart';
import 'screens/drivers_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/owners_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/operations_screen.dart';
import 'screens/reports_screen.dart';

// استيراد الشاشات الإضافية
import 'screens/settings_screen.dart';
import 'screens/account_statement_screen.dart';
import 'screens/add_user_screen.dart';
import 'screens/add_driver_screen.dart';
import 'screens/add_equipment_screen.dart';

// شاشة الدخول الجديدة
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F4C81),
          primary: const Color(0xFF0F4C81),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: const AuthGate(),
    );
  }
}

/// بوابة الدخول: تعرض شاشة تسجيل الدخول لو ما فيه جلسة نشطة،
/// أو الشاشة الرئيسية مباشرة لو المستخدم مسجّل دخوله فعلاً.
/// تستمع تلقائياً لأي تغيير بحالة الدخول (دخول/خروج) وتحدّث الواجهة فوراً.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session != null) {
          return const MainLayout();
        }
        return const LoginScreen();
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
            child: const Text('إلغاء'),
          ),
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
      // AuthGate بيتحول تلقائياً لشاشة الدخول عبر الستريم
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = supabase.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.balance, color: Color(0xFF0F4C81)),
            SizedBox(width: 8),
            Text(
              'ميزان',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F4C81),
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF0F4C81)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF0F4C81)),
            tooltip: 'تصدير تقرير لوحة التحكم PDF',
            onPressed: () => _generateAndPrintPdf(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0F4C81)),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  'م',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4C81),
                  ),
                ),
              ),
              accountName: const Text(
                'مدير النظام',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
                    leading: const Icon(Icons.account_balance_wallet,
                        color: Color(0xFF0F4C81)),
                    title: const Text('كشف حساب الملاك والموردين'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const AccountStatementScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.person_add, color: Color(0xFF0F4C81)),
                    title: const Text('إضافة مستخدم جديد'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AddUserScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.badge, color: Color(0xFF0F4C81)),
                    title: const Text('إضافة سائق (سريع)'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AddDriverScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_shipping,
                        color: Color(0xFF0F4C81)),
                    title: const Text('إضافة معدة بالنوع والموديل'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AddEquipmentScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.settings, color: Color(0xFF0F4C81)),
                    title: const Text('الإعدادات'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SettingsScreen()),
                      );
                    },
                  ),
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
            ? const Color(0xFF0F4C81).withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: isSelected ? const Color(0xFF0F4C81) : Colors.grey[700]),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF0F4C81) : Colors.black87,
          ),
        ),
        selected: isSelected,
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _generateAndPrintPdf(BuildContext context) async {
    final pdf = pw.Document();

    double totalRev = 0;
    double totalOwner = 0;
    double totalDriver = 0;
    try {
      final ops = await supabase.from('operations').select();
      for (var op in ops) {
        totalRev += (op['revenue'] ?? 0) as num;
        totalOwner += (op['owner_net'] ?? 0) as num;
        totalDriver += (op['driver_net'] ?? 0) as num;
      }
    } catch (_) {}

    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('تطبيق ميزان - تقرير لوحة التحكم',
                        style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 20,
                            color: PdfColors.blue900)),
                    pw.Text(
                        'التاريخ: ${DateTime.now().toString().substring(0, 10)}',
                        style: pw.TextStyle(font: font, fontSize: 12)),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Text('الملخص المالي العام:',
                    style: pw.TextStyle(font: fontBold, fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Container(
                        width: 6,
                        height: 6,
                        decoration: const pw.BoxDecoration(
                            color: PdfColors.black, shape: pw.BoxShape.circle)),
                    pw.SizedBox(width: 8),
                    pw.Text('إجمالي الإيرادات المسجلة: $totalRev ر.س',
                        style: pw.TextStyle(font: font, fontSize: 14)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Container(
                        width: 6,
                        height: 6,
                        decoration: const pw.BoxDecoration(
                            color: PdfColors.black, shape: pw.BoxShape.circle)),
                    pw.SizedBox(width: 8),
                    pw.Text('إجمالي مستحقات الملاك: $totalOwner ر.س',
                        style: pw.TextStyle(font: font, fontSize: 14)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Container(
                        width: 6,
                        height: 6,
                        decoration: const pw.BoxDecoration(
                            color: PdfColors.black, shape: pw.BoxShape.circle)),
                    pw.SizedBox(width: 8),
                    pw.Text('إجمالي مستحقات السائقين: $totalDriver ر.س',
                        style: pw.TextStyle(font: font, fontSize: 14)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'تقرير_ميزان_المالي.pdf',
    );
  }
}
