import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/theme_currency_provider.dart';
import '../utils/formatters.dart';
import '../utils/constants.dart';
import 'category_icon_widget.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDeleteButton;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
    this.showDeleteButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final categories = Provider.of<CategoryProvider>(context).categories;
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;

    final allCats = categories.isNotEmpty ? categories : AppConstants.defaultCategories;
    final catMatch = allCats.firstWhere(
      (c) => c.name.toLowerCase() == transaction.category.toLowerCase(),
      orElse: () => allCats.first,
    );

    final isIncome = transaction.type == TransactionType.income;
    final amountColor = isIncome ? const Color(0xFF00B894) : const Color(0xFFFF7675);
    final sign = isIncome ? '+' : '-';

    final Widget tileWidget = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isIncome
                ? const Color(0xFF00B894).withValues(alpha: 0.06)
                : const Color(0xFFFF7675).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Category Icon with Transaction Type Badge
                CategoryIconWidget(
                  category: catMatch,
                  transactionType: transaction.type,
                  size: 48,
                  iconSize: 22,
                  showTypeBadge: true,
                ),
                const SizedBox(width: 14),

                // Category & Description / Payment Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              transaction.category,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 0.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Text(
                            '$sign ${Formatters.formatCurrency(transaction.amount, symbol: currency)}',
                            style: TextStyle(
                              color: amountColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Where from? (Merchant / App / Source)
                      if (transaction.description.isNotEmpty &&
                          transaction.description.trim().toLowerCase() != transaction.category.trim().toLowerCase()) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              size: 12,
                              color: const Color(0xFF6C5CE7).withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                transaction.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                      ],

                      // Notes / Reason (if present)
                      if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.notes_rounded,
                              size: 11,
                              color: const Color(0xFF6C5CE7).withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                transaction.notes!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],

                      // Tags (if present)
                      if (transaction.tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: transaction.tags.take(3).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6C5CE7),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 5),
                      ],

                      // Bottom Metadata Pill Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Payment Method Badge
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: transaction.paymentMethod == 'Credit Card'
                                          ? const Color(0xFF6C5CE7).withValues(alpha: 0.15)
                                          : (Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white.withValues(alpha: 0.08)
                                              : Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          transaction.paymentMethod == 'Credit Card'
                                              ? Icons.credit_card_rounded
                                              : transaction.paymentMethod == 'UPI'
                                                  ? Icons.qr_code_scanner_rounded
                                                  : Icons.account_balance_wallet_outlined,
                                          size: 11,
                                          color: transaction.paymentMethod == 'Credit Card'
                                              ? const Color(0xFF6C5CE7)
                                              : Theme.of(context).textTheme.bodySmall?.color,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            transaction.paymentMethod,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: transaction.paymentMethod == 'Credit Card'
                                                  ? const Color(0xFF6C5CE7)
                                                  : Theme.of(context).textTheme.bodySmall?.color,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Bank / Card Badge
                                Flexible(
                                  child: _buildBankBadge(transaction),
                                ),

                                // Recurring Badge (if active)
                                if (transaction.isRecurring) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.repeat_rounded, size: 10, color: Color(0xFF6C5CE7)),
                                  ),
                                ],

                                // Receipt Attached Badge (if present)
                                if (transaction.receiptPath != null) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00B894).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.receipt_long_rounded, size: 10, color: Color(0xFF00B894)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Time Stamp
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 11,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                Formatters.formatShortDateTime(transaction.date),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Delete Button (if explicitly enabled)
                if (showDeleteButton && onDelete != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    onPressed: onDelete,
                    tooltip: 'Delete Transaction',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (onDelete == null) return tileWidget;

    return Dismissible(
      key: ValueKey('tx_slide_del_${transaction.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF7675),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Delete Transaction?'),
            content: Text(
              'Are you sure you want to delete "${transaction.category}" (${Formatters.formatCurrency(transaction.amount, symbol: currency)})?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) {
        onDelete?.call();
      },
      child: tileWidget,
    );
  }

  /// Extracts bank/card details from description and renders a pill badge.
  Widget _buildBankBadge(TransactionModel t) {
    String? bankName;

    // Detect known bank names in description
    final descLower = t.description.toLowerCase();
    const banks = [
      'Utkarsh', 'HDFC', 'SBI', 'ICICI', 'Axis', 'Kotak', 'PNB',
      'Bank of Baroda', 'BOB', 'IndusInd', 'Yes Bank', 'Federal Bank',
      'RBL Bank', 'IDFC', 'Bandhan', 'AU Small', 'Equitas', 'Canara',
      'Union Bank', 'Bank of India', 'BOI'
    ];

    for (final b in banks) {
      if (descLower.contains(b.toLowerCase())) {
        bankName = b == 'BOB' ? 'BOB' : b;
        break;
      }
    }

    // Also check for card masked last 4 pattern e.g. ••2235
    final cardMatch = RegExp(r'[•\*]{1,4}(\d{4})').firstMatch(t.description);
    String? cardDigits = cardMatch != null ? '••${cardMatch.group(1)}' : null;

    if (bankName == null && cardDigits == null) {
      return const SizedBox.shrink();
    }

    final displayText = bankName != null && cardDigits != null
        ? '$bankName $cardDigits'
        : (bankName ?? cardDigits!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF00CEC9).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_rounded, size: 10, color: Color(0xFF00B894)),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              displayText,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00838F),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
