import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  bool darkModeEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات العامة'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F4C81),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('إعدادات التطبيق',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F4C81))),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('تفعيل الإشعارات'),
            subtitle:
                const Text('تلقي تنبيهات عند إضافة عمليات أو مستحقات جديدة'),
            value: notificationsEnabled,
            onChanged: (val) {
              setState(() {
                notificationsEnabled = val;
              });
            },
          ),
          SwitchListTile(
            title: const Text('الوضع الليلي'),
            subtitle: const Text('تغيير مظهر التطبيق إلى الوضع الداكن'),
            value: darkModeEnabled,
            onChanged: (val) {
              setState(() {
                darkModeEnabled = val;
              });
            },
          ),
          const Divider(height: 30),
          const Text('معلومات النظام',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F4C81))),
          const SizedBox(height: 10),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('إصدار التطبيق'),
            subtitle: Text('1.0.0+1'),
          ),
          const ListTile(
            leading: Icon(Icons.business),
            title: Text('اسم النظام'),
            subtitle: Text('ميزان - لإدارة المعدات الثقيلة'),
          ),
        ],
      ),
    );
  }
}
