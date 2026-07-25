import 'dart:async';
import 'package:flutter/material.dart';

/// Type of transaction event for visual styling.
enum TransactionNotificationType { income, expense, deleted }

/// Shows a premium floating notification card for a transaction event.
/// Auto-dismisses after [duration] (default 2.5 s). Call via [show].
class TransactionNotification {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String title,
    required String amount,
    required String category,
    required String currency,
    required TransactionNotificationType type,
    String? description,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    // Cancel any existing notification immediately
    _dismiss();

    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TransactionNotificationCard(
        title: title,
        amount: amount,
        category: category,
        currency: currency,
        type: type,
        description: description,
        onDismiss: () => _dismiss(),
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, _dismiss);
  }

  static void _dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _TransactionNotificationCard extends StatefulWidget {
  final String title;
  final String amount;
  final String category;
  final String currency;
  final TransactionNotificationType type;
  final String? description;
  final VoidCallback onDismiss;

  const _TransactionNotificationCard({
    required this.title,
    required this.amount,
    required this.category,
    required this.currency,
    required this.type,
    required this.onDismiss,
    this.description,
  });

  @override
  State<_TransactionNotificationCard> createState() =>
      _TransactionNotificationCardState();
}

class _TransactionNotificationCardState
    extends State<_TransactionNotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (widget.type) {
      case TransactionNotificationType.income:
        return const Color(0xFF00B894);
      case TransactionNotificationType.expense:
        return const Color(0xFFFF7675);
      case TransactionNotificationType.deleted:
        return const Color(0xFFFDCB6E);
    }
  }

  IconData get _typeIcon {
    switch (widget.type) {
      case TransactionNotificationType.income:
        return Icons.arrow_downward_rounded;
      case TransactionNotificationType.expense:
        return Icons.arrow_upward_rounded;
      case TransactionNotificationType.deleted:
        return Icons.delete_outline_rounded;
    }
  }

  String get _amountPrefix {
    switch (widget.type) {
      case TransactionNotificationType.income:
        return '+';
      case TransactionNotificationType.expense:
        return '-';
      case TransactionNotificationType.deleted:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);
    final subTextColor = isDark ? Colors.white54 : Colors.grey.shade600;
    final mediaQuery = MediaQuery.of(context);

    return Positioned(
      top: mediaQuery.padding.top + 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: GestureDetector(
              onTap: widget.onDismiss,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < 0) {
                  widget.onDismiss();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _accentColor.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withValues(alpha: 0.18),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Colored accent bar on the left
                      Container(width: 5, color: _accentColor),

                      // Main content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              // Icon bubble
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: _accentColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _typeIcon,
                                  color: _accentColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Text block
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            widget.title,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: subTextColor,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: subTextColor.withValues(alpha: 0.5),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            widget.category,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_amountPrefix}${widget.currency}${widget.amount}',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: _accentColor,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (widget.description != null &&
                                        widget.description!.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        widget.description!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: subTextColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
