import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../widgets/balance_summary_card.dart';
import '../../widgets/ai_insight_card.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/transaction_notification.dart';
import '../authentication/login_screen.dart';
import '../profile/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// App brand colours (mirrors AppTheme without importing it)
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFF6C5CE7);
const _kPrimaryLt = Color(0xFF8E7CFE);
const _kIncome    = Color(0xFF00B894);
const _kTeal      = Color(0xFF00CEC9);

class HomeDashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAll;
  const HomeDashboardScreen({super.key, this.onSeeAll});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen>
    with TickerProviderStateMixin {
  late Timer _timer;
  late DateTime _now;

  // Staggered entrance controllers
  late AnimationController _headerCtrl;
  late AnimationController _cardsCtrl;
  late AnimationController _txCtrl;

  late Animation<double>  _headerFade, _cardsFade, _txFade;
  late Animation<Offset>  _headerSlide, _cardsSlide, _txSlide;

  // Rotating shimmer on avatar ring
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    AnimationController makeCtrl(int ms) => AnimationController(
          vsync: this,
          duration: Duration(milliseconds: ms),
        );

    _headerCtrl = makeCtrl(500);
    _cardsCtrl  = makeCtrl(480);
    _txCtrl     = makeCtrl(480);

    Animation<double> fade(AnimationController c) =>
        CurvedAnimation(parent: c, curve: Curves.easeOut);
    Animation<Offset> slide(AnimationController c, Offset from) =>
        Tween<Offset>(begin: from, end: Offset.zero)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic));

    _headerFade  = fade(_headerCtrl);
    _cardsFade   = fade(_cardsCtrl);
    _txFade      = fade(_txCtrl);
    _headerSlide = slide(_headerCtrl, const Offset(0, -0.2));
    _cardsSlide  = slide(_cardsCtrl,  const Offset(0,  0.15));
    _txSlide     = slide(_txCtrl,     const Offset(0,  0.15));

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Stagger the animations
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _headerCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 160));
      _cardsCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 140));
      _txCtrl.forward();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _headerCtrl.dispose();
    _cardsCtrl.dispose();
    _txCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = _now.hour;
    if (h < 5)  return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _greetingEmoji() {
    final h = _now.hour;
    if (h < 5)  return '🌙';
    if (h < 12) return '☀️';
    if (h < 17) return '🌤️';
    return '🌆';
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Logout Account'),
          ],
        ),
        content: const Text('Are you sure you want to log out of Pocketify?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.pop(dialogContext);
              final auth =
                  Provider.of<AuthProvider>(context, listen: false);
              await auth.logout();
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final txProvider   = Provider.of<TransactionProvider>(context);
    final recentTx     = txProvider.transactions.take(5).toList();
    final theme        = Theme.of(context);
    final isDark       = theme.brightness == Brightness.dark;

    final timeString = DateFormat('hh:mm a').format(_now);
    final dateString = DateFormat('EEE, d MMM').format(_now);
    final userName   = authProvider.currentUser?.name ?? 'User';
    final initial    = userName.characters.first.toUpperCase();

    final bg = isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF2F4FA);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // ── Background atmosphere blobs ────────────────────────────────
          _BlobBg(isDark: isDark),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [

                // ── Header ───────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: SlideTransition(
                      position: _headerSlide,
                      child: _buildHeader(
                        context,
                        isDark: isDark,
                        userName: userName,
                        initial: initial,
                        timeString: timeString,
                        dateString: dateString,
                      ),
                    ),
                  ),
                ),


                // ── Balance + AI cards ────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _cardsFade,
                      child: SlideTransition(
                        position: _cardsSlide,
                        child: Column(
                          children: [
                            const BalanceSummaryCard(),
                            const SizedBox(height: 14),
                            const AIInsightCard(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Recent transactions ───────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  sliver: SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _txFade,
                      child: SlideTransition(
                        position: _txSlide,
                        child: Column(
                          children: [
                            _buildSectionHeader(
                              context,
                              isDark: isDark,
                              count: recentTx.length,
                            ),
                            const SizedBox(height: 14),
                            if (recentTx.isEmpty)
                              _buildEmptyState(isDark)
                            else
                              ...recentTx.map(
                                (t) => TransactionTile(
                                  transaction: t,
                                  onDelete: () {
                                    final c = Provider.of<ThemeCurrencyProvider>(
                                      context,
                                      listen: false,
                                    ).currency;
                                    txProvider.deleteTransaction(t.id);
                                    TransactionNotification.show(
                                      context,
                                      title: 'Transaction Deleted',
                                      amount: t.amount % 1 == 0
                                          ? t.amount.toInt().toString()
                                          : t.amount.toString(),
                                      category: t.category,
                                      currency: c,
                                      type: TransactionNotificationType.deleted,
                                      description: t.description.isNotEmpty
                                          ? t.description
                                          : t.paymentMethod,
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context, {
    required bool isDark,
    required String userName,
    required String initial,
    required String timeString,
    required String dateString,
  }) {
    final subtleColor = isDark
        ? Colors.white.withValues(alpha: 0.42)
        : Colors.black.withValues(alpha: 0.38);
    final boldColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with animated shimmer ring
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: AnimatedBuilder(
              animation: _shimmerCtrl,
              builder: (_, child) {
                return CustomPaint(
                  painter: _RingPainter(
                    progress: _shimmerCtrl.value,
                    isDark: isDark,
                  ),
                  child: child,
                );
              },
              child: Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(3),
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_kPrimary, _kPrimaryLt],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: _kIncome,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF0E0E1A)
                                : const Color(0xFFF2F4FA),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),

          // Greeting
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_greetingEmoji()} ${_greeting()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: subtleColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: boldColor,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Clock chip
          _ClockChip(time: timeString, date: dateString, isDark: isDark),
          const SizedBox(width: 6),

          // Logout
          _HeaderIconBtn(
            icon: Icons.logout_rounded,
            isDark: isDark,
            iconColor: Colors.red.withValues(alpha: 0.80),
            onTap: _showLogoutDialog,
          ),
        ],
      ),
    );
  }


  // ── Section header ───────────────────────────────────────────────────────

  Widget _buildSectionHeader(
    BuildContext context, {
    required bool isDark,
    required int count,
  }) {
    final boldColor   = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Row(
      children: [
        // Accent bar
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kPrimary, _kTeal],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Recent Transactions',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: boldColor,
            letterSpacing: -0.3,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _kPrimary,
              ),
            ),
          ),
        ],
        const Spacer(),
        GestureDetector(
          onTap: widget.onSeeAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _kPrimary.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                  ),
                ),
                SizedBox(width: 3),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 10, color: _kPrimary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : _kPrimary.withValues(alpha: 0.10),
          width: 1.5,
          // Dashed feel via strokeAlign (border is solid but subtle)
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.09),
              shape: BoxShape.circle,
              border: Border.all(
                color: _kPrimary.withValues(alpha: 0.18),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 32,
              color: _kPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF2D3436),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the + button below to add\nyour first transaction.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.32),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background atmospheric blobs
// ─────────────────────────────────────────────────────────────────────────────

class _BlobBg extends StatelessWidget {
  final bool isDark;
  const _BlobBg({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Top-left purple blob
        Positioned(
          top: -size.height * 0.10,
          left: -size.width * 0.22,
          child: Container(
            width: size.width * 0.80,
            height: size.width * 0.80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _kPrimary.withValues(alpha: isDark ? 0.18 : 0.09),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Bottom-right teal blob
        Positioned(
          bottom: size.height * 0.08,
          right: -size.width * 0.28,
          child: Container(
            width: size.width * 0.70,
            height: size.width * 0.70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _kTeal.withValues(alpha: isDark ? 0.12 : 0.07),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Clock chip
// ─────────────────────────────────────────────────────────────────────────────

class _ClockChip extends StatelessWidget {
  final String time;
  final String date;
  final bool isDark;

  const _ClockChip({
    required this.time,
    required this.date,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _kPrimary.withValues(alpha: isDark ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _kPrimary.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time_filled_rounded,
                  size: 11, color: _kPrimary),
              const SizedBox(width: 4),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _kPrimary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            date,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: _kPrimary.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header icon button
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final Color? iconColor;

  const _HeaderIconBtn({
    required this.icon,
    required this.isDark,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.60)
            : Colors.black.withValues(alpha: 0.42));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer ring painter for avatar
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  const _RingPainter({required this.progress, required this.isDark});

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
        colors: [
          _kPrimary.withValues(alpha: 0),
          _kPrimary.withValues(alpha: 0.9),
          _kTeal.withValues(alpha: 0.7),
          _kPrimary.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
