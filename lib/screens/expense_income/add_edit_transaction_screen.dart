import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../services/local_storage_service.dart';
import '../../services/sms_parser_service.dart';
import '../../services/smart_categorizer_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/transaction_notification.dart';
import '../../widgets/category_icon_widget.dart';

class AddEditTransactionScreen extends StatefulWidget {
  final bool isExpense;
  final TransactionModel? transactionToEdit;

  const AddEditTransactionScreen({
    super.key,
    this.isExpense = true,
    this.transactionToEdit,
  });

  @override
  State<AddEditTransactionScreen> createState() => _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _isExpense;

  late TextEditingController _amountController;
  late TextEditingController _descriptionController; // Title / Merchant
  late TextEditingController _notesController; // Notes for what it was for

  String _selectedCategory = 'Food';
  String _selectedPaymentMethod = 'UPI';
  String? _selectedCardLast4;
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;
  String? _receiptPath;

  @override
  void initState() {
    super.initState();
    _isExpense = widget.isExpense;
    final edit = widget.transactionToEdit;

    _amountController = TextEditingController(
      text: edit != null
          ? (edit.amount % 1 == 0
              ? edit.amount.toInt().toString()
              : edit.amount.toString())
          : '',
    );
    _descriptionController = TextEditingController(text: edit?.description ?? '');
    _notesController = TextEditingController(text: edit?.notes ?? '');
    _descriptionController.addListener(_onDescriptionChanged);

    if (edit != null) {
      _selectedCategory = edit.category;
      _selectedPaymentMethod = edit.paymentMethod;
      _selectedDate = edit.date;
      _isRecurring = edit.isRecurring;
      _receiptPath = edit.receiptPath;
    } else {
      _selectedCategory = _isExpense ? 'Food' : 'Salary';
      _checkClipboardAutoDetect();
    }
  }

  void _onDescriptionChanged() {
    final text = _descriptionController.text;
    final predicted = SmartCategorizerService.predictCategory(text, isExpense: _isExpense);
    if (predicted != null && predicted != _selectedCategory) {
      setState(() {
        _selectedCategory = predicted;
      });
    }
  }

  void _checkClipboardAutoDetect() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text;
      if (text != null && text.isNotEmpty && text.length < 500) {
        final result = SMSParserService.parseSMS(text);
        if (result != null && mounted) {
          setState(() {
            _amountController.text = result.amount % 1 == 0
                ? result.amount.toInt().toString()
                : result.amount.toString();
            _isExpense = result.type == TransactionType.expense;
            _selectedCategory = result.category;
            _selectedPaymentMethod = result.paymentMethod;
            _descriptionController.text = result.merchant;
          });
        }
      }
    } catch (_) {
      // Ignore clipboard read errors gracefully
    }
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(_amountController.text.trim());
      final txProvider = Provider.of<TransactionProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);

      final activeUid = authProvider.currentUser?.uid ?? 'local_user';

      final rawCategories = categoryProvider.categories;
      final categories = rawCategories.isNotEmpty ? rawCategories : AppConstants.defaultCategories;
      final matchingCategories = categories
          .where((c) => c.isIncome == !_isExpense)
          .where((c) => !['Business', 'Freelance', 'Rental Income', 'Rental'].contains(c.name))
          .toList();
      final filteredCategories = matchingCategories.isNotEmpty ? matchingCategories : categories;

      final saveCategory = filteredCategories.any((c) => c.name == _selectedCategory)
          ? _selectedCategory
          : (filteredCategories.isNotEmpty ? filteredCategories.first.name : 'Food');

      final rawDesc = _descriptionController.text.trim();
      String finalDesc = rawDesc;

      // If Credit Card was chosen and user picked a card, append card last4 tag
      if (_selectedPaymentMethod == 'Credit Card') {
        final rawCards = LocalStorageService.getCreditCards();
        final effectiveLast4 = _selectedCardLast4 ?? (rawCards.isNotEmpty ? (rawCards.first['last4'] as String?) : null);
        if (effectiveLast4 != null && effectiveLast4.isNotEmpty && !finalDesc.contains('••')) {
          finalDesc = finalDesc.isEmpty ? 'Credit Card ••$effectiveLast4' : '$finalDesc (Card ••$effectiveLast4)';
        }
      }

      final notesText = _notesController.text.trim();

      final transaction = TransactionModel(
        id: widget.transactionToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        uid: widget.transactionToEdit?.uid ?? activeUid,
        type: _isExpense ? TransactionType.expense : TransactionType.income,
        amount: amount,
        category: saveCategory,
        paymentMethod: _selectedPaymentMethod,
        description: finalDesc.isNotEmpty ? finalDesc : saveCategory,
        notes: notesText.isNotEmpty ? notesText : null,
        receiptPath: _receiptPath,
        date: _selectedDate,
        isRecurring: _isRecurring,
      );

      if (widget.transactionToEdit == null) {
        await txProvider.addTransaction(transaction);
      } else {
        await txProvider.updateTransaction(transaction);
      }

      if (!mounted) return;

      Navigator.pop(context);

      if (context.mounted) {
        final currency = Provider.of<ThemeCurrencyProvider>(context, listen: false).currency;
        final isEditing = widget.transactionToEdit != null;
        TransactionNotification.show(
          context,
          title: isEditing
              ? (_isExpense ? 'Expense Updated' : 'Income Updated')
              : (_isExpense ? 'Expense Added' : 'Income Added'),
          amount: amount % 1 == 0
              ? amount.toInt().toString()
              : amount.toString(),
          category: saveCategory,
          currency: currency,
          type: _isExpense
              ? TransactionNotificationType.expense
              : TransactionNotificationType.income,
          description: finalDesc.isNotEmpty
              ? finalDesc
              : (notesText.isNotEmpty ? notesText : _selectedPaymentMethod),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawCategories = Provider.of<CategoryProvider>(context).categories;
    final categories = rawCategories.isNotEmpty ? rawCategories : AppConstants.defaultCategories;

    final matchingCategories = categories
        .where((c) => c.isIncome == !_isExpense)
        .where((c) => !['Business', 'Freelance', 'Rental Income', 'Rental'].contains(c.name))
        .toList();
    final filteredCategories = matchingCategories.isNotEmpty ? matchingCategories : categories;

    final currentCategory = filteredCategories.any((c) => c.name == _selectedCategory)
        ? _selectedCategory
        : (filteredCategories.isNotEmpty ? filteredCategories.first.name : 'Food');

    final currentPaymentMethod = AppConstants.paymentMethods.contains(_selectedPaymentMethod)
        ? _selectedPaymentMethod
        : AppConstants.paymentMethods.first;

    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transactionToEdit != null
              ? 'Edit Transaction'
              : (_isExpense ? 'Add Expense' : 'Add Income'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Toggle (Expense / Income)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpense = true;
                          final defaultExpenseCat = categories.firstWhere(
                            (c) => !c.isIncome,
                            orElse: () => categories.isNotEmpty ? categories.first : AppConstants.defaultCategories.first,
                          );
                          _selectedCategory = defaultExpenseCat.name;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _isExpense ? const Color(0xFFFF7675) : (isDark ? const Color(0xFF28293D) : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Expense',
                          style: TextStyle(
                            color: _isExpense ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpense = false;
                          final defaultIncomeCat = categories.firstWhere(
                            (c) => c.isIncome,
                            orElse: () => categories.isNotEmpty ? categories.first : AppConstants.defaultCategories.first,
                          );
                          _selectedCategory = defaultIncomeCat.name;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: !_isExpense ? const Color(0xFF00B894) : (isDark ? const Color(0xFF28293D) : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Income',
                          style: TextStyle(
                            color: !_isExpense ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Amount Input
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$currency ',
                  prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: cardBg,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter amount';
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) return 'Please enter valid number';
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Category Selector
              DropdownButtonFormField<String>(
                key: ValueKey('cat_${_isExpense}_$currentCategory'),
                initialValue: currentCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: cardBg,
                ),
                items: filteredCategories.map((cat) {
                  return DropdownMenuItem(
                    value: cat.name,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CategoryIconWidget(
                          category: cat,
                          size: 26,
                          iconSize: 13,
                          showTypeBadge: true,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(cat.name, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 18),

              // Payment Method Selector
              DropdownButtonFormField<String>(
                key: ValueKey('pm_$currentPaymentMethod'),
                initialValue: currentPaymentMethod,
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: cardBg,
                ),
                items: AppConstants.paymentMethods.map((method) {
                  return DropdownMenuItem(value: method, child: Text(method));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPaymentMethod = val);
                },
              ),
              const SizedBox(height: 18),

              // Specific Credit Card Picker (if Credit Card)
              if (_selectedPaymentMethod == 'Credit Card') ...[
                _buildCreditCardPicker(),
                const SizedBox(height: 18),
              ],

              // Date & Time Picker Tile
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF6C5CE7)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date & Time', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          const SizedBox(height: 2),
                          Text(
                            Formatters.formatShortDateTime(_selectedDate),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Where from? (Merchant / App / Transit / Store)
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: _isExpense ? 'Where from? (Merchant / App / Transit)' : 'Where from? (Source / Payer)',
                  hintText: _isExpense ? 'e.g. Flipkart, Swiggy, Auto / Bus, Amazon, Uber...' : 'e.g. Employer, Client, Bank, Friend...',
                  prefixIcon: const Icon(Icons.storefront_rounded, color: Color(0xFF6C5CE7), size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: cardBg,
                ),
              ),
              const SizedBox(height: 8),

              // Quick "Where from" Suggestion Chips (Flexible 2-3 Rows)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (_isExpense
                    ? const ['Flipkart', 'Swiggy', 'Auto / Bus', 'Amazon', 'Zomato', 'Blinkit', 'Uber', 'Zepto', 'Metro', 'Netflix', 'Fuel Station']
                    : const ['Salary / Employer', 'Freelance / Client', 'Bank Interest', 'Friend', 'Cashback']
                ).map((source) {
                  final isSel = _descriptionController.text.trim().toLowerCase() == source.toLowerCase();
                  return ActionChip(
                    avatar: isSel
                        ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                        : null,
                    label: Text(source),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _descriptionController.text = source;
                        if (source == 'Auto / Bus' || source == 'Uber' || source == 'Metro') {
                          _selectedCategory = 'Travel';
                        } else if (source == 'Flipkart' || source == 'Amazon') {
                          _selectedCategory = 'Shopping';
                        } else if (source == 'Swiggy' || source == 'Zomato') {
                          _selectedCategory = 'Food';
                        } else if (source == 'Blinkit' || source == 'Zepto') {
                          _selectedCategory = 'Grocery';
                        } else if (source == 'Netflix') {
                          _selectedCategory = 'Entertainment';
                        } else if (source == 'Fuel Station') {
                          _selectedCategory = 'Fuel';
                        } else {
                          final predicted = SmartCategorizerService.predictCategory(source, isExpense: _isExpense);
                          if (predicted != null) {
                            _selectedCategory = predicted;
                          }
                        }
                      });
                    },
                    backgroundColor: isSel
                        ? const Color(0xFF6C5CE7)
                        : (isDark ? const Color(0xFF28293D) : Colors.grey.shade100),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF2D3436)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSel ? const Color(0xFF6C5CE7) : (isDark ? Colors.white12 : Colors.grey.shade300),
                        width: 0.8,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Notes ("What was it for?") Field
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes / What was it for? (Optional)',
                  hintText: 'e.g. Shoes order, dinner with team, daily commute, flat rent...',
                  prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF6C5CE7), size: 22),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: cardBg,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),

              // Save / Update Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isExpense ? const Color(0xFFFF7675) : const Color(0xFF00B894),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    widget.transactionToEdit != null
                        ? 'Update Transaction'
                        : (_isExpense ? 'Save Expense' : 'Save Income'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditCardPicker() {
    final rawCards = LocalStorageService.getCreditCards();
    if (rawCards.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF6C5CE7), size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No credit cards registered. Tap Add Card on home dashboard to track limits.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6C5CE7)),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedCardLast4 ?? rawCards.first['last4'] as String?,
      decoration: InputDecoration(
        labelText: 'Select Credit Card',
        prefixIcon: const Icon(Icons.credit_card_rounded, color: Color(0xFF6C5CE7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      items: rawCards.map((c) {
        final cardName = c['cardName'] as String? ?? 'Card';
        final last4 = c['last4'] as String? ?? '0000';
        return DropdownMenuItem<String>(
          value: last4,
          child: Text('$cardName (••$last4)'),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _selectedCardLast4 = val);
      },
    );
  }
}
