import 'dart:async';
import 'package:flutter/material.dart';

/// Type of transaction event for visual styling.
enum TransactionNotificationType { income, expense, deleted }

// ─────────────────────────────────────────────────────────────────────────────
// Public API — same signature as before, fully backward-compatible
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a native-feeling floating notification card that matches the
/// Pocketify design system. Auto-dismisses after [duration] (default 1.5 s).
class TransactionNotification {
  static OverlayEntry? _entry;
  static Timer? _timer;
  static _CardState? _state;

  static void show(
    BuildContext context, {
    required String title,
    required String amount,
    required String category,
    required String currency,
    required TransactionNotificationType type,
    String? description,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    _cancelCurrent();

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NotifCard(
        title: title,
        amount: amount,
        category: category,
        currency: currency,
        type: type,
        description: description,
        duration: duration,
        onDismiss: _animatedDismiss,
        onState: (s) => _state = s,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, _animatedDismiss);
  }

  static void _animatedDismiss() {
    _timer?.cancel();
    _timer = null;
    _state?.slideOut().then((_) {
      _entry?.remove();
      _entry = null;
      _state = null;
    });
  }

  static void _cancelCurrent() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
    _state = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class _NotifCard extends StatefulWidget {
  final String title;
  final String amount;
  final String category;
  final String currency;
  final TransactionNotificationType type;
  final String? description;
  final Duration duration;
  final VoidCallback onDismiss;
  final ValueChanged<_CardState> onState;

  const _NotifCard({
    required this.title,
    required this.amount,
    required this.category,
    required this.currency,
    required this.type,
    required this.duration,
    required this.onDismiss,
    required this.onState,
    this.description,
  });

  @override
  State<_NotifCard> createState() => _CardState();
}

class _CardState extends State<_NotifCard> with TickerProviderStateMixin {
  // Slide + fade in/out
  late final AnimationController _entryCtrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  // Timer bar draining left→right
  late final AnimationController _barCtrl;
  late final Animation<double> _bar;

  Future<void> slideOut() async {
    if (!_entryCtrl.isCompleted) return;
    _barCtrl.stop();
    await _entryCtrl.animateTo(0,
        duration: const Duration(milliseconds: 260), curve: Curves.easeInCubic);
  }

  @override
  void initState() {
    super.initState();
    widget.onState(this);

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slide = Tween<Offset>(begin: const Offset(0, -1.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(
        parent: _entryCtrl, curve: const Interval(0, 0.55, curve: Curves.easeOut));

    _barCtrl = AnimationController(vsync: this, duration: widget.duration);
    _bar = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _barCtrl, curve: Curves.linear));

    _entryCtrl.forward().then((_) => _barCtrl.forward());
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  // ── Theming helpers ──────────────────────────────────────────────────────

  /// The semantic colour for this notification type, sourced from AppTheme.
  Color _typeColor(ColorScheme cs) {
    switch (widget.type) {
      case TransactionNotificationType.income:
        return const Color(0xFF00B894); // AppTheme.successColor
      case TransactionNotificationType.expense:
        return const Color(0xFFFF7675); // AppTheme.dangerColor
      case TransactionNotificationType.deleted:
        return const Color(0xFFFDCB6E); // AppTheme.warningColor
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case TransactionNotificationType.income:
        return Icons.south_rounded;
      case TransactionNotificationType.expense:
        return Icons.north_rounded;
      case TransactionNotificationType.deleted:
        return Icons.delete_outline_rounded;
    }
  }

  String get _prefix {
    switch (widget.type) {
      case TransactionNotificationType.income:
        return '+';
      case TransactionNotificationType.expense:
        return '-';
      case TransactionNotificationType.deleted:
        return '';
    }
  }

  /// Smart subtitle: prefer description, else derive from title.
  String _smartSubtitle() {
    final desc = widget.description?.trim();
    if (desc != null && desc.isNotEmpty) return desc;
    // Derive from title e.g. "Expense Added" → "Added to records"
    final t = widget.title.toLowerCase();
    if (t.contains('added')) return 'Added to your records';
    if (t.contains('updated')) return 'Entry updated successfully';
    if (t.contains('deleted')) return 'Removed from records';
    return widget.title;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final color = _typeColor(cs);

    // Card surface matches the app's card color exactly
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final onCard = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subtle = isDark
        ? Colors.white.withValues(alpha: 0.42)
        : const Color(0xFF6B7280);

    return Positioned(
      top: mq.padding.top + 8,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              onTap: widget.onDismiss,
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < -150) widget.onDismiss();
              },
              child: _buildCard(
                color: color,
                cardColor: cardColor,
                onCard: onCard,
                subtle: subtle,
                isDark: isDark,
                cs: cs,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required Color color,
    required Color cardColor,
    required Color onCard,
    required Color subtle,
    required bool isDark,
    required ColorScheme cs,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.22 : 0.18),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.20 : 0.14),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Main row ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon chip — matches app card icon style
                  _IconChip(color: color, icon: _icon, isDark: isDark),
                  const SizedBox(width: 11),

                  // Text block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top row: header label + time hint
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: subtle,
                                  letterSpacing: 0.1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Now',
                              style: TextStyle(
                                fontSize: 10,
                                color: subtle.withValues(alpha: 0.65),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),

                        // Category + amount row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                widget.category,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: onCard,
                                  letterSpacing: -0.2,
                                  height: 1.15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_prefix${widget.currency}${widget.amount}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: color,
                                letterSpacing: -0.4,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),

                        // Smart subtitle
                        const SizedBox(height: 2),
                        Text(
                          _smartSubtitle(),
                          style: TextStyle(
                            fontSize: 11,
                            color: subtle,
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Dismiss button
                  const SizedBox(width: 8),
                  _DismissButton(onTap: widget.onDismiss, subtle: subtle),
                ],
              ),
            ),

            // ── Countdown timer bar ──────────────────────────────────────────
            _TimerBar(animation: _bar, color: color, isDark: isDark),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _IconChip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final bool isDark;

  const _IconChip({
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.30 : 0.20),
          width: 1.0,
        ),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _DismissButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color subtle;

  const _DismissButton({required this.onTap, required this.subtle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.close_rounded,
          size: 16,
          color: subtle.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _TimerBar extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  final bool isDark;

  const _TimerBar({
    required this.animation,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) => SizedBox(
        height: 3,
        child: Stack(
          children: [
            // Track (always full width)
            Container(
              width: double.infinity,
              color: color.withValues(alpha: isDark ? 0.10 : 0.08),
            ),
            // Filled portion drains from right
            FractionallySizedBox(
              widthFactor: animation.value.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(
                color: color.withValues(alpha: isDark ? 0.72 : 0.60),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
