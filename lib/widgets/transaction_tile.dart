import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/theme_currency_provider.dart';
import '../utils/formatters.dart';
import '../utils/constants.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
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

    return Container(
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
                // Category Icon with Gradient Aura Ring
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: catMatch.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: catMatch.color.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(catMatch.iconData, color: catMatch.color, size: 22),
                  ),
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

                      // Description / Note (if present)
                      if (transaction.description.isNotEmpty) ...[
                        Text(
                          transaction.description,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
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

                // Delete Button (if provided)
                if (onDelete != null) ...[
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
