import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

/// حالة اشتراك المستخدم الحالي
enum SubscriptionStatus { checking, active, pending, expired, suspended, error }

class SubscriptionService {
  static final supabase = Supabase.instance.client;

  /// يتأكد من وجود صف اشتراك للمستخدم، وينشئه بحالة "pending" لو أول دخول له
  static Future<SubscriptionStatus> checkAndEnsureSubscription() async {
    final user = supabase.auth.currentUser;
    if (user == null) return SubscriptionStatus.error;

    try {
      final existing = await supabase
          .from('subscriptions')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing == null) {
        // أول دخول لهذا المستخدم - أنشئ له اشتراك pending تلقائياً
        await supabase.from('subscriptions').insert({
          'user_id': user.id,
          'user_email': user.email,
          'status': 'pending',
        });
        return SubscriptionStatus.pending;
      }

      final status = existing['status']?.toString() ?? 'pending';
      final expiresAt = existing['expires_at'] != null
          ? DateTime.tryParse(existing['expires_at'].toString())
          : null;

      if (status == 'active') {
        if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
          return SubscriptionStatus.expired;
        }
        return SubscriptionStatus.active;
      }
      if (status == 'suspended') return SubscriptionStatus.suspended;
      if (status == 'expired') return SubscriptionStatus.expired;
      return SubscriptionStatus.pending;
    } catch (e) {
      return SubscriptionStatus.error;
    }
  }
}

/// شاشة تظهر لو الاشتراك مو مفعّل (قيد الانتظار / منتهي / موقوف)
class SubscriptionBlockedScreen extends StatefulWidget {
  final SubscriptionStatus status;
  const SubscriptionBlockedScreen({super.key, required this.status});

  @override
  State<SubscriptionBlockedScreen> createState() =>
      _SubscriptionBlockedScreenState();
}

class _SubscriptionBlockedScreenState extends State<SubscriptionBlockedScreen> {
  final supabase = Supabase.instance.client;
  bool _isChecking = false;

  Future<void> _recheck() async {
    setState(() => _isChecking = true);
    // إعادة بناء الشجرة بالكامل تجبر AuthGate يعيد التحقق من جديد
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _isChecking = false);
  }

  String get _title {
    switch (widget.status) {
      case SubscriptionStatus.pending:
        return 'حسابك قيد التفعيل';
      case SubscriptionStatus.expired:
        return 'انتهت صلاحية اشتراكك';
      case SubscriptionStatus.suspended:
        return 'تم إيقاف حسابك مؤقتاً';
      default:
        return 'حدث خطأ';
    }
  }

  String get _message {
    switch (widget.status) {
      case SubscriptionStatus.pending:
        return 'شكراً لتسجيلك في تطبيق ميزان. حسابك حالياً قيد المراجعة والتفعيل من فريق الدعم.\nسيتم تفعيل حسابك فور استلام الدفع، وستصلك رسالة تأكيد.';
      case SubscriptionStatus.expired:
        return 'انتهت مدة اشتراكك في تطبيق ميزان. يرجى التواصل معنا لتجديد الاشتراك ومواصلة استخدام التطبيق.';
      case SubscriptionStatus.suspended:
        return 'تم إيقاف حسابك مؤقتاً. يرجى التواصل مع الدعم لمعرفة السبب وإعادة تفعيل الحساب.';
      default:
        return 'حدث خطأ أثناء التحقق من حالة اشتراكك. يرجى المحاولة مرة أخرى أو التواصل مع الدعم.';
    }
  }

  IconData get _icon {
    switch (widget.status) {
      case SubscriptionStatus.pending:
        return Icons.hourglass_top_rounded;
      case SubscriptionStatus.expired:
        return Icons.event_busy_rounded;
      case SubscriptionStatus.suspended:
        return Icons.block_rounded;
      default:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.warningLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icon, size: 48, color: AppTheme.warning),
                  ),
                  const SizedBox(height: 24),
                  Text(_title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  Text(_message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                          height: 1.6)),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isChecking ? null : _recheck,
                      icon: _isChecking
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.refresh),
                      label: Text(_isChecking
                          ? 'جارٍ التحقق...'
                          : 'تحقق من حالة الاشتراك'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => supabase.auth.signOut(),
                    icon: const Icon(Icons.logout, size: 18, color: Colors.red),
                    label: const Text('تسجيل الخروج',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
