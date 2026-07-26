import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/theme_currency_provider.dart';
import '../services/local_storage_service.dart';
import '../utils/formatters.dart';

// ─── Data model ─────────────────────────────────────────────────────────────
class CreditCardData {
  final String id;
  final String cardName;   // e.g. "SuperCard", "HDFC Millennia"
  final String last4;      // e.g. "2235"
  final double limit;      // credit limit in ₹

  CreditCardData({
    required this.id,
    required this.cardName,
    required this.last4,
    required this.limit,
  });

  Map<String, dynamic> toMap() =>
      {'id': id, 'cardName': cardName, 'last4': last4, 'limit': limit};

  factory CreditCardData.fromMap(Map<String, dynamic> m) => CreditCardData(
        id: m['id'] as String,
        cardName: m['cardName'] as String,
        last4: m['last4'] as String,
        limit: (m['limit'] as num).toDouble(),
      );
}

// ─── Main widget ─────────────────────────────────────────────────────────────
class CreditCardSummaryWidget extends StatefulWidget {
  const CreditCardSummaryWidget({super.key});

  @override
  State<CreditCardSummaryWidget> createState() =>
      _CreditCardSummaryWidgetState();
}

class _CreditCardSummaryWidgetState extends State<CreditCardSummaryWidget> {
  List<CreditCardData> _cards = [];

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  void _loadCards() {
    setState(() {
      _cards = LocalStorageService.getCreditCards()
          .map(CreditCardData.fromMap)
          .toList();
    });
  }

  Future<void> _saveCard(CreditCardData card) async {
    await LocalStorageService.saveCreditCard(card.toMap());
    _loadCards();
    if (mounted) {
      Provider.of<TransactionProvider>(context, listen: false).loadTransactions();
    }
  }

  Future<void> _deleteCard(String id) async {
    await LocalStorageService.deleteCreditCard(id);
    _loadCards();
    if (mounted) {
      Provider.of<TransactionProvider>(context, listen: false).loadTransactions();
    }
  }

  Future<void> _showAddEditDialog({CreditCardData? existing}) async {
    final nameCtrl =
        TextEditingController(text: existing?.cardName ?? '');
    final last4Ctrl =
        TextEditingController(text: existing?.last4 ?? '');
    final limitCtrl = TextEditingController(
        text: existing != null ? existing.limit.toStringAsFixed(0) : '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2D3436), Color(0xFF636e72)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.credit_card,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      existing == null ? 'Add Credit Card' : 'Edit Card',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Card name
                TextFormField(
                  controller: nameCtrl,
                  decoration: _inputDecoration(
                      'Card Name', 'e.g. SuperCard, HDFC Millennia'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter card name' : null,
                ),
                const SizedBox(height: 14),

                // Last 4 digits
                TextFormField(
                  controller: last4Ctrl,
                  decoration:
                      _inputDecoration('Last 4 Digits', 'e.g. 2235'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter last 4 digits';
                    if (v.trim().length != 4) return 'Must be exactly 4 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Credit limit
                TextFormField(
                  controller: limitCtrl,
                  decoration: _inputDecoration('Credit Limit (₹)', 'e.g. 100000'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter credit limit';
                    final d = double.tryParse(v.trim());
                    if (d == null || d <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    if (existing != null)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        label: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteCard(existing.id);
                        },
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D3436),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          final card = CreditCardData(
                            id: existing?.id ??
                                DateTime.now().millisecondsSinceEpoch.toString(),
                            cardName: nameCtrl.text.trim(),
                            last4: last4Ctrl.text.trim(),
                            limit:
                                double.parse(limitCtrl.text.trim()),
                          );
                          Navigator.pop(ctx);
                          _saveCard(card);
                        }
                      },
                      child: Text(existing == null ? 'Add Card' : 'Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final currency =
        Provider.of<ThemeCurrencyProvider>(context).currency;

    // Per-card spent this month from transactions
    final cardSpentMap = txProvider.creditCardSpendingByCard;
    // Total CC spent
    final totalSpent = txProvider.totalCreditCardSpent;
    // Total limit across all registered cards
    final totalLimit =
        _cards.fold<double>(0, (s, c) => s + c.limit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ─────────────────────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D3436), Color(0xFF636e72)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.credit_card_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Credit Cards',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            // Add card button
            GestureDetector(
              onTap: () => _showAddEditDialog(existing: _cards.isNotEmpty ? _cards.first : null),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D3436).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF2D3436).withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_cards.isNotEmpty ? Icons.edit_outlined : Icons.add, size: 14, color: const Color(0xFF2D3436)),
                    const SizedBox(width: 4),
                    Text(_cards.isNotEmpty ? 'Edit Card' : 'Add Card',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3436))),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Empty state ────────────────────────────────────────────────
        if (_cards.isEmpty) ...[
          _EmptyCardPrompt(onAdd: () => _showAddEditDialog()),
        ] else ...[
          // ── Total summary banner ───────────────────────────────────
          if (_cards.length > 1)
            _TotalBanner(
              totalSpent: totalSpent,
              totalLimit: totalLimit,
              currency: currency,
              txCount: txProvider.creditCardTransactions.length,
            ),
          if (_cards.length > 1) const SizedBox(height: 12),

          // ── Individual cards ───────────────────────────────────────
          ...List.generate(_cards.length, (i) {
            final card = _cards[i];
            // Match spent from transactions — try ••last4 key first
            final spentKey = '••${card.last4}';
            final spent = cardSpentMap[spentKey] ??
                cardSpentMap['Credit Card'] ??
                0.0;
            final fraction = card.limit > 0
                ? (spent / card.limit).clamp(0.0, 1.0)
                : 0.0;

            final gradients = [
              [const Color(0xFF2D3436), const Color(0xFF4a4f52)],
              [const Color(0xFF1a1a2e), const Color(0xFF16213e)],
              [const Color(0xFF0f3460), const Color(0xFF533483)],
              [const Color(0xFF1B262C), const Color(0xFF0F4C75)],
            ];
            final grad = gradients[i % gradients.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _CreditCardTile(
                card: card,
                spent: spent,
                fraction: fraction,
                currency: currency,
                gradColors: grad,
                onEdit: () => _showAddEditDialog(existing: card),
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ─── Empty prompt ─────────────────────────────────────────────────────────────
class _EmptyCardPrompt extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCardPrompt({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.25),
            width: 1.5,
            style: BorderStyle.solid,
          ),
          color: Colors.grey.withValues(alpha: 0.04),
        ),
        child: Column(
          children: [
            Icon(Icons.add_card_rounded,
                size: 40, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Text(
              'Tap to add your credit card',
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Set your card limit & track spending',
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Total banner (shown when 2+ cards) ──────────────────────────────────────
class _TotalBanner extends StatelessWidget {
  final double totalSpent;
  final double totalLimit;
  final String currency;
  final int txCount;

  const _TotalBanner({
    required this.totalSpent,
    required this.totalLimit,
    required this.currency,
    required this.txCount,
  });

  @override
  Widget build(BuildContext context) {
    final fraction =
        totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0.0;
    final remaining = (totalLimit - totalSpent).clamp(0.0, totalLimit);
    final isOver = totalSpent > totalLimit && totalLimit > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Spent',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500)),
                    Text(
                      Formatters.formatCurrency(totalSpent, symbol: currency),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Remaining',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                  Text(
                    totalLimit > 0
                        ? Formatters.formatCurrency(remaining,
                            symbol: currency)
                        : '—',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isOver
                            ? const Color(0xFFFF7675)
                            : const Color(0xFF00B894)),
                  ),
                ],
              ),
            ],
          ),
          if (totalLimit > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 7,
                backgroundColor: Colors.grey.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOver
                      ? const Color(0xFFFF7675)
                      : fraction > 0.8
                          ? const Color(0xFFFDCB6E)
                          : const Color(0xFF00B894),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(fraction * 100).toStringAsFixed(0)}% used of ${Formatters.formatCurrency(totalLimit, symbol: currency)} limit',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade500),
                ),
                Text(
                  '$txCount transaction${txCount == 1 ? '' : 's'}',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Single credit card tile ──────────────────────────────────────────────────
class _CreditCardTile extends StatelessWidget {
  final CreditCardData card;
  final double spent;
  final double fraction;
  final String currency;
  final List<Color> gradColors;
  final VoidCallback onEdit;

  const _CreditCardTile({
    required this.card,
    required this.spent,
    required this.fraction,
    required this.currency,
    required this.gradColors,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (card.limit - spent).clamp(0.0, card.limit);
    final isOver = spent > card.limit;
    final barColor = isOver
        ? const Color(0xFFFF7675)
        : fraction > 0.8
            ? const Color(0xFFFDCB6E)
            : const Color(0xFF55efc4);

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: gradColors[0].withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: icon + edit hint
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Card chip graphic
                Container(
                  width: 34,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 15,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                // Limit badge + edit icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Limit ${Formatters.formatCurrency(card.limit, symbol: currency)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_outlined,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.6)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Row 2: card number
            Text(
              '•••• •••• •••• ${card.last4}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card.cardName,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 18),

            // Row 3: spent / remaining
            Row(
              children: [
                _statCol('Spent', Formatters.formatCurrency(spent, symbol: currency)),
                const SizedBox(width: 24),
                _statCol(
                  isOver ? 'Over Limit!' : 'Available',
                  isOver
                      ? '${Formatters.formatCurrency(spent - card.limit, symbol: currency)} over'
                      : Formatters.formatCurrency(remaining, symbol: currency),
                  color: isOver
                      ? const Color(0xFFFF7675)
                      : const Color(0xFF55efc4),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isOver
                  ? '⚠️ Limit exceeded!'
                  : '${(fraction * 100).toStringAsFixed(0)}% of limit used',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCol(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
