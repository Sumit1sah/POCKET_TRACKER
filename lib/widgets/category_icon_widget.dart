import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../utils/icon_helper.dart';

/// A clean, simple, flat badge widget that renders a Category's Icon cleanly
/// without gradients, shadows, or complex lighting effects.
class CategoryIconWidget extends StatelessWidget {
  final CategoryModel? category;
  final IconData? iconData;
  final Color? color;
  final bool? isIncome;
  final TransactionType? transactionType;
  final double size;
  final double? iconSize;
  final bool showTypeBadge;
  final BorderRadius? borderRadius;

  const CategoryIconWidget({
    super.key,
    this.category,
    this.iconData,
    this.color,
    this.isIncome,
    this.transactionType,
    this.size = 44.0,
    this.iconSize,
    this.showTypeBadge = true,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine whether this icon represents an Income or Expense transaction
    final bool effectiveIsIncome = transactionType != null
        ? transactionType == TransactionType.income
        : (isIncome ?? category?.isIncome ?? false);

    final effectiveIcon = iconData ??
        category?.iconData ??
        IconHelper.getIconForCategoryName(category?.name ?? '', isIncome: effectiveIsIncome);
    final effectiveColor = color ?? category?.color ?? const Color(0xFF6C5CE7);

    final double effectiveIconSize = iconSize ?? (size * 0.48);
    final BorderRadius effectiveRadius = borderRadius ?? BorderRadius.circular(size * 0.32);

    // Simple flat transaction type badge styling
    final Color badgeBg = effectiveIsIncome ? const Color(0xFF00B894) : const Color(0xFFFF7675);
    final IconData badgeIcon = effectiveIsIncome ? Icons.south_west_rounded : Icons.north_east_rounded;
    final double badgeSize = size * 0.36;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Simple, Flat Category Icon Container (No gradients, no shadows, no color lighting)
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: isDark ? 0.22 : 0.14),
            borderRadius: effectiveRadius,
          ),
          child: Center(
            child: Icon(
              effectiveIcon,
              color: effectiveColor,
              size: effectiveIconSize,
            ),
          ),
        ),

        // Simple Flat Transaction Type Badge (Income green ↙, Expense red/coral ↗)
        if (showTypeBadge)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: badgeBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  badgeIcon,
                  color: Colors.white,
                  size: badgeSize * 0.65,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
