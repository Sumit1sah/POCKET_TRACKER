import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/theme_currency_provider.dart';
import '../services/local_storage_service.dart';
import '../utils/formatters.dart';
import '../utils/app_theme.dart';
import '../widgets/credit_card_summary_widget.dart'; // reuse CreditCardData model

class BalanceSummaryCard extends StatefulWidget {
  const BalanceSummaryCard({super.key});

  @override
  State<BalanceSummaryCard> createState() => _BalanceSummaryCardState();
}

class _BalanceSummaryCardState extends State<BalanceSummaryCard> {
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

  Future<void> _showCardDialog({CreditCardData? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.cardName ?? '');
    final last4Ctrl = TextEditingController(text: existing?.last4 ?? '');
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
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.credit_card,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(existing == null ? 'Add Credit Card' : 'Edit Card',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameCtrl,
                  decoration: _inputDec('Card Name', 'e.g. SuperCard, HDFC Millennia'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter card name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: last4Ctrl,
                  decoration: _inputDec('Last 4 Digits', 'e.g. 2235'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length != 4) return 'Must be 4 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: limitCtrl,
                  decoration: _inputDec('Credit Limit (₹)', 'e.g. 100000'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final d = double.tryParse(v);
                    if (d == null || d <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(children: [
                  if (existing != null)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 18),
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
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
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
                              DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                          cardName: nameCtrl.text.trim(),
                          last4: last4Ctrl.text.trim(),
                          limit: double.parse(limitCtrl.text.trim()),
                        );
                        Navigator.pop(ctx);
                        _saveCard(card);
                      }
                    },
                    child: Text(existing == null ? 'Add Card' : 'Save'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;

    // ── Budget data ───────────────────────────────────────────────────────
    final overallStatus =
        budgetProvider.getOverallBudgetStatus(txProvider.transactions);
    final budgetLimit = overallStatus.budget.monthlyLimit;
    final budgetSpent = overallStatus.spent;
    final budgetRemaining = overallStatus.remaining;
    final budgetPct = overallStatus.percentage;

    Color budgetBadgeColor = const Color(0xFF00B894);
    String budgetBadgeText = 'On Track';
    if (overallStatus.isExceeded) {
      budgetBadgeColor = const Color(0xFFFF7675);
      budgetBadgeText = 'EXCEEDED';
    } else if (budgetPct >= 0.9) {
      budgetBadgeColor = const Color(0xFFFF7675);
      budgetBadgeText = '90% Used';
    } else if (budgetPct >= 0.8) {
      budgetBadgeColor = const Color(0xFFFDCB6E);
      budgetBadgeText = '80% Used';
    }

    // ── CC data ───────────────────────────────────────────────────────────
    final ccSpentMap = txProvider.creditCardSpendingByCard;
    final totalCCSpent = txProvider.totalCreditCardSpent;
    final totalCCLimit =
        _cards.fold<double>(0, (s, c) => s + c.limit);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section 1: Net Balance ───────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Net Balance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              _badge(Icons.shield_outlined, 'Secured',
                  Colors.white.withValues(alpha: 0.2)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            Formatters.formatCurrency(txProvider.netBalance, symbol: currency),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          if (txProvider.totalCreditLimit > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Bank: ${Formatters.formatCurrency(txProvider.bankAndCashBalance, symbol: currency)} + CC Avail: ${Formatters.formatCurrency(txProvider.totalCreditCardAvailableLimit, symbol: currency)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (txProvider.totalCreditCardSpent > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Bank: ${Formatters.formatCurrency(txProvider.bankAndCashBalance, symbol: currency)} • CC Due: ${Formatters.formatCurrency(txProvider.totalCreditCardSpent, symbol: currency)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Income & Expense compact tiles (current month - resets every month)
          Row(children: [
            Expanded(
              child: _summaryTile(
                title: 'Income',
                amount: txProvider.thisMonthIncome,
                icon: Icons.arrow_downward_rounded,
                color: const Color(0xFF00B894),
                currencySymbol: currency,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryTile(
                title: 'Expense',
                amount: txProvider.thisMonthExpense,
                icon: Icons.arrow_upward_rounded,
                color: const Color(0xFFFF7675),
                currencySymbol: currency,
              ),
            ),
          ]),

          // ── Divider ──────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 10),

          // ── Section 2: Monthly Budget ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white, size: 14),
                const SizedBox(width: 5),
                Text(
                  'Monthly Budget',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: budgetBadgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  budgetBadgeText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Remaining',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 10)),
                Text(
                  budgetLimit > 0
                      ? Formatters.formatCurrency(budgetRemaining,
                          symbol: currency)
                      : 'No Budget Set',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Spent / Limit',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 10)),
                Text(
                  budgetLimit > 0
                      ? '${Formatters.formatCurrency(budgetSpent, symbol: currency)} / ${Formatters.formatCurrency(budgetLimit, symbol: currency)}'
                      : 'Set in Budget Tab',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: budgetLimit > 0 ? budgetPct.clamp(0.0, 1.0) : 0.0,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor:
                  AlwaysStoppedAnimation<Color>(budgetBadgeColor),
            ),
          ),

          // ── Divider & Section 3: Credit Cards (Gated by preference) ───────
          if (LocalStorageService.getCCPreference() != false) ...[
            const SizedBox(height: 10),
            Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.credit_card_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    'Credit Cards',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
                GestureDetector(
                  onTap: () => _showCardDialog(existing: _cards.isNotEmpty ? _cards.first : null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(children: [
                      Icon(_cards.isNotEmpty ? Icons.edit_outlined : Icons.add, color: Colors.white, size: 11),
                      const SizedBox(width: 2),
                      Text(
                        _cards.isNotEmpty ? 'Edit Card' : 'Add Card',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 9,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Empty state
            if (_cards.isEmpty)
              GestureDetector(
                onTap: () => _showCardDialog(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_card_rounded,
                          color: Colors.white.withValues(alpha: 0.6), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to add credit card & set limit',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Total CC row (only when 2+ cards)
              if (_cards.length > 1 && totalCCLimit > 0) ...[
                _ccTotalRow(totalCCSpent, totalCCLimit, currency),
                const SizedBox(height: 6),
              ],

              // Individual card rows
              ..._cards.asMap().entries.map((e) {
                final card = e.value;
                final last4Spent = ccSpentMap['••${card.last4}'] ?? 0.0;
                final genericSpent = _cards.length == 1 ? 0.0 : (ccSpentMap['Credit Card'] ?? 0.0);
                final spent = _cards.length == 1 ? totalCCSpent : (last4Spent + genericSpent);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _ccCardRow(card, spent, currency),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  // ── CC total summary row ─────────────────────────────────────────────────
  Widget _ccTotalRow(double spent, double limit, String currency) {
    final pct = (spent / limit).clamp(0.0, 1.0);
    final remaining = (limit - spent).clamp(0.0, limit);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Due: ${Formatters.formatCurrency(spent, symbol: currency)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                'Total Limit: ${Formatters.formatCurrency(limit, symbol: currency)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                pct > 0.9
                    ? const Color(0xFFFF7675)
                    : pct > 0.8
                        ? const Color(0xFFFDCB6E)
                        : const Color(0xFF55efc4),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(pct * 100).toStringAsFixed(0)}% used',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 9),
              ),
              Text(
                'Avail: ${Formatters.formatCurrency(remaining, symbol: currency)}',
                style: const TextStyle(
                    color: Color(0xFF55efc4),
                    fontSize: 9,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Individual CC card compact row ────────────────────────────────────────
  Widget _ccCardRow(CreditCardData card, double spent, String currency) {
    final pct =
        card.limit > 0 ? (spent / card.limit).clamp(0.0, 1.0) : 0.0;
    final remaining = (card.limit - spent).clamp(0.0, card.limit);
    final isOver = spent > card.limit && card.limit > 0;

    final barColor = isOver
        ? const Color(0xFFFF7675)
        : pct > 0.8
            ? const Color(0xFFFDCB6E)
            : const Color(0xFF55efc4);

    return GestureDetector(
      onTap: () => _showCardDialog(existing: card),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.15), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Card chip icon
              Container(
                width: 28,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Container(
                    width: 16,
                    height: 11,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Card name & number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.cardName,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '•••• •••• •••• ${card.last4}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 9,
                          letterSpacing: 1.5),
                    ),
                  ],
                ),
              ),
              // Due & Total Limit
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Due: ',
                      style: TextStyle(
                        color: isOver ? const Color(0xFFFF7675) : Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      Formatters.formatCurrency(spent, symbol: currency),
                      style: TextStyle(
                        color: isOver ? const Color(0xFFFF7675) : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  card.limit > 0
                      ? 'Limit: ${Formatters.formatCurrency(card.limit, symbol: currency)}'
                      : 'No limit set',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ]),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.4), size: 16),
            ]),
            if (card.limit > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}% used of ${Formatters.formatCurrency(card.limit, symbol: currency)} limit',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 9),
                  ),
                  Text(
                    isOver
                        ? '⚠️ Over limit'
                        : 'Avail: ${Formatters.formatCurrency(remaining, symbol: currency)}',
                    style: TextStyle(
                        color: isOver ? const Color(0xFFFF7675) : const Color(0xFF55efc4),
                        fontSize: 9,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helper: icon + text badge ────────────────────────────────────────────
  Widget _badge(IconData icon, String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 4),
        Text(label,
            style:
                TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
      ]),
    );
  }

  // ── Summary income/expense tile ──────────────────────────────────────────
  Widget _summaryTile({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required String currencySymbol,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
            Text(
              Formatters.formatCurrency(amount, symbol: currencySymbol),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
      ]),
    );
  }
}
