import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/local_storage_service.dart';
import 'services/sms_auto_capture_service.dart';
import 'providers/auth_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/category_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/savings_provider.dart';
import 'providers/theme_currency_provider.dart';
import 'utils/app_theme.dart';
import 'screens/splash/splash_screen.dart';

/// Native Android platform channel for SMS interception
const _smsChannel = MethodChannel('com.example.expense_tracker/sms');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.init();

  // Listen for SMS events pushed from native Android SmsReceiver
  _smsChannel.setMethodCallHandler((call) async {
    if (call.method == 'onSmsReceived') {
      final smsBody = call.arguments as String?;
      if (smsBody != null && smsBody.isNotEmpty) {
        await SmsAutoCaptureService.captureFromSms(smsBody);
      }
    }
  });

  runApp(const PocketifyApp());
}

class PocketifyApp extends StatelessWidget {
  const PocketifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth is always first — all user-scoped providers depend on it
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeCurrencyProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),

        // TransactionProvider reacts to AuthProvider changes automatically
        ChangeNotifierProxyProvider<AuthProvider, TransactionProvider>(
          create: (_) => TransactionProvider(),
          update: (_, auth, previous) {
            final provider = previous ?? TransactionProvider();
            provider.loadForUser(auth.currentUser?.uid);
            return provider;
          },
        ),

        // BudgetProvider reacts to AuthProvider changes automatically
        ChangeNotifierProxyProvider<AuthProvider, BudgetProvider>(
          create: (_) => BudgetProvider(),
          update: (_, auth, previous) {
            final provider = previous ?? BudgetProvider();
            provider.loadForUser(auth.currentUser?.uid);
            return provider;
          },
        ),

        ChangeNotifierProvider(create: (_) => SavingsProvider()),
      ],
      child: Consumer2<ThemeCurrencyProvider, AuthProvider>(
        builder: (context, themeProvider, authProvider, child) {
          return MaterialApp(
            title: 'Pocketify - Smart Expense Tracker',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            scrollBehavior: const SmoothScrollBehavior(),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

/// Wraps any screen and requests SMS permission on first launch.
class _PermissionGateScreen extends StatefulWidget {
  final Widget child;
  const _PermissionGateScreen({required this.child});

  @override
  State<_PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<_PermissionGateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestSmsPermission());
  }

  Future<void> _requestSmsPermission() async {
    final status = await Permission.sms.status;
    if (status.isGranted) return;
    if (status.isPermanentlyDenied) {
      _showGoToSettingsDialog();
      return;
    }
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sms_rounded, color: Color(0xFF6C5CE7), size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Auto-Capture Transactions',
                    style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pocketify needs SMS permission to automatically detect and log your transactions from:',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 12),
                _BulletRow(icon: Icons.currency_rupee, text: 'Google Pay / GPay'),
                _BulletRow(icon: Icons.currency_rupee, text: 'PhonePe'),
                _BulletRow(icon: Icons.currency_rupee, text: 'Paytm'),
                _BulletRow(icon: Icons.account_balance, text: 'Bank SMS Alerts'),
                SizedBox(height: 12),
                Text(
                  '🔒 Your SMS data never leaves your device.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Skip for Now'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await Permission.sms.request();
              },
              child: const Text('Allow SMS Access'),
            ),
          ],
        ),
      );
    }
  }

  void _showGoToSettingsDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('SMS Permission Required'),
        content: const Text(
          'SMS permission was denied. To enable auto-capture:\n\nSettings → Apps → Pocketify → Permissions → SMS → Allow',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BulletRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BulletRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6C5CE7)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
