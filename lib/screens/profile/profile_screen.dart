import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/biometric_service.dart';
import '../../services/local_storage_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../reports/reports_screen.dart';
import '../categories/categories_screen.dart';
import '../calendar/calendar_screen.dart';
import '../authentication/login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand tokens
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimary  = Color(0xFF6C5CE7);
const _kTeal     = Color(0xFF00CEC9);
const _kPink     = Color(0xFFFD79A8);
const _kIncome   = Color(0xFF00B894);
const _kExpense  = Color(0xFFFF7675);
const _kWarning  = Color(0xFFFDCB6E);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;

  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    // Load persisted biometric preference
    _biometricEnabled = LocalStorageService.getBiometricEnabled();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────

  void _showEditProfileDialog(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final nameCtrl  = TextEditingController(text: auth.currentUser?.name ?? '');
    final emailCtrl = TextEditingController(text: auth.currentUser?.email ?? '');

    _showStyledDialog(
      context,
      icon: Icons.person_rounded,
      iconColor: _kPrimary,
      title: 'Edit Profile',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StyledField(controller: nameCtrl,  label: 'Full Name',      icon: Icons.person_outline),
          const SizedBox(height: 14),
          _StyledField(controller: emailCtrl, label: 'Email Address',  icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress),
        ],
      ),
      actionLabel: 'Save Changes',
      onAction: () async {
        final n = nameCtrl.text.trim();
        final e = emailCtrl.text.trim();
        if (n.isEmpty || e.isEmpty) return;
        await auth.updateProfileDetails(n, e);
        if (context.mounted) {
          Navigator.pop(context);
          _toast(context, '✅ Profile updated successfully!');
        }
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final auth     = Provider.of<AuthProvider>(context, listen: false);
    final currCtrl = TextEditingController();
    final newCtrl  = TextEditingController();
    final confCtrl = TextEditingController();
    final formKey  = GlobalKey<FormState>();

    _showStyledDialog(
      context,
      icon: Icons.lock_reset_rounded,
      iconColor: _kPrimary,
      title: 'Change Password',
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StyledField(controller: currCtrl, label: 'Current Password',
                icon: Icons.lock_outline, obscure: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Enter current password' : null),
            const SizedBox(height: 14),
            _StyledField(controller: newCtrl, label: 'New Password',
                icon: Icons.key_outlined, obscure: true,
                validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null),
            const SizedBox(height: 14),
            _StyledField(controller: confCtrl, label: 'Confirm Password',
                icon: Icons.check_circle_outline, obscure: true,
                validator: (v) => v != newCtrl.text ? 'Passwords do not match' : null),
          ],
        ),
      ),
      actionLabel: 'Update Password',
      onAction: () async {
        if (formKey.currentState!.validate()) {
          await auth.changePassword(currCtrl.text, newCtrl.text);
          if (context.mounted) {
            Navigator.pop(context);
            _toast(context, '🔐 Password changed successfully!');
          }
        }
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kPrimary, _kTeal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.wallet_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                const Text('Pocketify',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('Smart Expense Tracker',
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white54
                            : Colors.black45)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Version 1.0.0 · Production Release',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kPrimary)),
                ),
                const SizedBox(height: 18),
                Text(
                  'Offline-first storage · Real-time analytics · AI spending insights · Budget tracking · PDF/CSV exports · Calendar view · Auto SMS capture.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Close',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.logout_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('Logout Account'),
        ]),
        content: const Text('Are you sure you want to log out of Pocketify?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              await auth.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                );
              }
            },
            child: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Generic styled dialog ────────────────────────────────────────────────

  void _showStyledDialog(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget content,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: iconColor.withValues(alpha: 0.20), width: 1),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 20),
              content,
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(actionLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _toggleBiometric(bool val) async {
    if (val) {
      final available = await BiometricService.isAvailable();
      if (!available) {
        if (mounted) {
          _toast(context, '⚠️ Biometric / PIN lock is not available on this device');
        }
        return;
      }
      final authenticated = await BiometricService.authenticate(
        reason: 'Authenticate to enable Security Lock',
      );
      if (authenticated) {
        await LocalStorageService.setBiometricEnabled(true);
        if (mounted) {
          setState(() => _biometricEnabled = true);
          _toast(context, '🔒 Biometric / PIN lock enabled');
        }
      } else {
        if (mounted) {
          _toast(context, '❌ Authentication failed or cancelled');
        }
      }
    } else {
      await LocalStorageService.setBiometricEnabled(false);
      if (mounted) {
        setState(() => _biometricEnabled = false);
        _toast(context, '🔓 Biometric / PIN lock disabled');
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth      = Provider.of<AuthProvider>(context);
    final theme     = Provider.of<ThemeCurrencyProvider>(context);
    final txP       = Provider.of<TransactionProvider>(context);
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final currency  = theme.currency;

    final userName  = auth.currentUser?.name ?? 'User';
    final userEmail = auth.currentUser?.email ?? '';
    final initial   = userName.characters.first.toUpperCase();

    final bg = isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF2F4FA);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Atmosphere blobs
          _buildBg(isDark),

          CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // ── App Bar ──────────────────────────────────────────────────
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                expandedHeight: 0,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Profile & Settings',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    letterSpacing: -0.3,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => _confirmLogout(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.20),
                              width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout_rounded,
                                size: 14, color: Colors.red),
                            SizedBox(width: 5),
                            Text('Logout',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // ── Hero Avatar Card ────────────────────────────────
                    _buildHeroCard(
                      context,
                      isDark: isDark,
                      initial: initial,
                      userName: userName,
                      userEmail: userEmail,
                      txP: txP,
                      currency: currency,
                    ),
                    const SizedBox(height: 20),

                    // ── Account & Security ──────────────────────────────
                    _SectionLabel(label: 'ACCOUNT & SECURITY', isDark: isDark),
                    const SizedBox(height: 10),
                    _SettingsCard(isDark: isDark, children: [
                      _SettingsTile(
                        icon: Icons.person_rounded,
                        iconColor: _kPrimary,
                        title: 'Edit Profile Details',
                        subtitle: 'Update your name & email',
                        isDark: isDark,
                        onTap: () => _showEditProfileDialog(context),
                      ),
                      _Divider(isDark: isDark),
                      _SettingsTile(
                        icon: Icons.lock_reset_rounded,
                        iconColor: _kPrimary,
                        title: 'Change Password',
                        subtitle: 'Update account security',
                        isDark: isDark,
                        onTap: () => _showChangePasswordDialog(context),
                      ),
                      _Divider(isDark: isDark),
                      _SwitchTile(
                        icon: Icons.fingerprint_rounded,
                        iconColor: _kPrimary,
                        title: 'Biometric / PIN Lock',
                        subtitle: 'Require auth to open app',
                        value: _biometricEnabled,
                        isDark: isDark,
                        onChanged: (val) => _toggleBiometric(val),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Preferences ─────────────────────────────────────
                    _SectionLabel(label: 'PREFERENCES', isDark: isDark),
                    const SizedBox(height: 10),
                    _SettingsCard(isDark: isDark, children: [
                      // Currency row with inline dropdown
                      _CurrencyTile(
                        isDark: isDark,
                        current: currency,
                        currencies: AppConstants.defaultCurrencies,
                        onChanged: (val) {
                          if (val != null) theme.setCurrency(val);
                        },
                      ),
                      _Divider(isDark: isDark),
                      _SwitchTile(
                        icon: Icons.dark_mode_rounded,
                        iconColor: _kTeal,
                        title: 'Dark Mode',
                        subtitle: theme.isDarkMode
                            ? 'Currently: Dark theme'
                            : 'Currently: Light theme',
                        value: theme.isDarkMode,
                        isDark: isDark,
                        onChanged: (val) => theme.toggleDarkMode(val),
                      ),
                      _Divider(isDark: isDark),
                      _SwitchTile(
                        icon: Icons.notifications_active_rounded,
                        iconColor: _kTeal,
                        title: 'Push Notifications',
                        subtitle: 'Budget alerts & reminders',
                        value: _notificationsEnabled,
                        isDark: isDark,
                        onChanged: (val) =>
                            setState(() => _notificationsEnabled = val),
                      ),
                      _Divider(isDark: isDark),
                      _SwitchTile(
                        icon: Icons.credit_card_rounded,
                        iconColor: _kPrimary,
                        title: 'Credit Card Tracking',
                        subtitle: 'Show CC limits on dashboard',
                        value: LocalStorageService.getCCPreference() ?? false,
                        isDark: isDark,
                        onChanged: (val) async {
                          await LocalStorageService.setCCPreference(val);
                          setState(() {});
                          _toast(context,
                              val ? '💳 CC tracking enabled' : '💳 CC tracking disabled');
                        },
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Features & Tools ─────────────────────────────────
                    _SectionLabel(label: 'FEATURES & TOOLS', isDark: isDark),
                    const SizedBox(height: 10),
                    _SettingsCard(isDark: isDark, children: [
                      _SettingsTile(
                        icon: Icons.calendar_month_rounded,
                        iconColor: _kPink,
                        title: 'Calendar View',
                        subtitle: 'Browse by date',
                        isDark: isDark,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const CalendarScreen())),
                      ),
                      _Divider(isDark: isDark),
                      _SettingsTile(
                        icon: Icons.category_rounded,
                        iconColor: _kPink,
                        title: 'Category Management',
                        subtitle: 'Add, edit & delete categories',
                        isDark: isDark,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const CategoriesScreen())),
                      ),
                      _Divider(isDark: isDark),
                      _SettingsTile(
                        icon: Icons.picture_as_pdf_rounded,
                        iconColor: _kPink,
                        title: 'Reports & Exports',
                        subtitle: 'Generate PDF / CSV reports',
                        isDark: isDark,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const ReportsScreen())),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Support & About ──────────────────────────────────
                    _SectionLabel(label: 'SUPPORT & ABOUT', isDark: isDark),
                    const SizedBox(height: 10),
                    _SettingsCard(isDark: isDark, children: [
                      _SettingsTile(
                        icon: Icons.info_rounded,
                        iconColor: Colors.blue,
                        title: 'About Pocketify',
                        subtitle: 'Version 1.0.0',
                        isDark: isDark,
                        onTap: () => _showAboutDialog(context),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // ── Logout button ─────────────────────────────────────
                    _LogoutButton(onTap: () => _confirmLogout(context)),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Hero avatar + stats card ─────────────────────────────────────────────

  Widget _buildHeroCard(
    BuildContext context, {
    required bool isDark,
    required String initial,
    required String userName,
    required String userEmail,
    required TransactionProvider txP,
    required String currency,
  }) {
    final cardColor =
        isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _kPrimary.withValues(alpha: isDark ? 0.20 : 0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with shimmer ring
          GestureDetector(
            onTap: () => _showEditProfileDialog(context),
            child: AnimatedBuilder(
              animation: _shimmerCtrl,
              builder: (_, child) => CustomPaint(
                painter: _RingPainter(progress: _shimmerCtrl.value),
                child: child,
              ),
              child: Container(
                width: 86,
                height: 86,
                padding: const EdgeInsets.all(4),
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_kPrimary, Color(0xFF8E7CFE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(initial,
                            style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: cardColor, width: 2),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(userName,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  letterSpacing: -0.4)),
          const SizedBox(height: 3),
          Text(userEmail,
              style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.42)
                      : Colors.black.withValues(alpha: 0.38))),
          const SizedBox(height: 18),

          // Stats row
          Row(children: [
            _MiniStat(
              label: 'Total Income',
              value: Formatters.formatCurrency(txP.totalIncome, symbol: currency),
              color: _kIncome,
              isDark: isDark,
            ),
            _VertDivider(isDark: isDark),
            _MiniStat(
              label: 'Total Expense',
              value: Formatters.formatCurrency(txP.totalExpense, symbol: currency),
              color: _kExpense,
              isDark: isDark,
            ),
            _VertDivider(isDark: isDark),
            _MiniStat(
              label: 'Transactions',
              value: '${txP.transactions.length}',
              color: _kPrimary,
              isDark: isDark,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildBg(bool isDark) {
    return Stack(children: [
      Positioned(
        top: -80,
        left: -60,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _kPrimary.withValues(alpha: isDark ? 0.16 : 0.08),
              Colors.transparent,
            ]),
          ),
        ),
      ),
      Positioned(
        bottom: 100,
        right: -60,
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _kTeal.withValues(alpha: isDark ? 0.12 : 0.06),
              Colors.transparent,
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: isDark
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.35),
        ));
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;
  const _SettingsCard({required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                    color: iconColor.withValues(alpha: 0.18), width: 1),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.40)
                              : Colors.black.withValues(alpha: 0.38))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: 0.25)),
          ]),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
            border:
                Border.all(color: iconColor.withValues(alpha: 0.18), width: 1),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark ? Colors.white : const Color(0xFF1A1A2E))),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.40)
                          : Colors.black.withValues(alpha: 0.38))),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.85,
          child: Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: _kPrimary,
          ),
        ),
      ]),
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  final bool isDark;
  final String current;
  final List<String> currencies;
  final ValueChanged<String?> onChanged;

  const _CurrencyTile({
    required this.isDark,
    required this.current,
    required this.currencies,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _kTeal.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: _kTeal.withValues(alpha: 0.18), width: 1),
          ),
          child: const Icon(Icons.currency_exchange_rounded,
              color: _kTeal, size: 18),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Primary Currency',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A2E))),
              const SizedBox(height: 2),
              Text('Select your default currency',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.40)
                          : Colors.black.withValues(alpha: 0.38))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _kTeal.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: _kTeal.withValues(alpha: 0.22), width: 1),
          ),
          child: DropdownButton<String>(
            value: current,
            underline: const SizedBox.shrink(),
            isDense: true,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kTeal,
            ),
            dropdownColor:
                isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            items: currencies
                .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700))))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04),
      indent: 67,
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.38)
                    : Colors.black.withValues(alpha: 0.35))),
      ]),
    );
  }
}

class _VertDivider extends StatelessWidget {
  final bool isDark;
  const _VertDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.07),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.red.withValues(alpha: 0.22), width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.red, size: 18),
            SizedBox(width: 8),
            Text('Logout Account',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// Reusable styled text field for dialogs.
class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _StyledField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer ring painter
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final angle  = progress * 2 * math.pi;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: angle,
        endAngle: angle + math.pi,
        colors: const [
          Color(0x006C5CE7),
          Color(0xFF6C5CE7),
          Color(0xFF00CEC9),
          Color(0x006C5CE7),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
