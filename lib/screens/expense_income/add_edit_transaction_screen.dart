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
  late TextEditingController _descriptionController;

  String _selectedCategory = 'Food';
  String _selectedPaymentMethod = 'UPI';
  String? _selectedCardLast4;
  DateTime _selectedDate = DateTime.now();
  String? _receiptPath;
  bool _isRecurring = false;
  String? _autoDetectedCategory;

  @override
  void initState() {
    super.initState();
    _isExpense = widget.isExpense;
    final edit = widget.transactionToEdit;
    _amountController = TextEditingController(text: edit != null ? edit.amount.toStringAsFixed(0) : '');
    _descriptionController = TextEditingController(text: edit?.description ?? '');
    _descriptionController.addListener(_onDescriptionChanged);
    if (edit != null) {
      _selectedCategory = edit.category;
      _selectedPaymentMethod = edit.paymentMethod;
      _selectedDate = edit.date;
      _receiptPath = edit.receiptPath;
      _isRecurring = edit.isRecurring;
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
        _autoDetectedCategory = predicted;
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
            _amountController.text = result.amount.toStringAsFixed(0);
            _isExpense = result.type == TransactionType.expense;
            _selectedCategory = result.category;
            _selectedPaymentMethod = result.paymentMethod;
            _descriptionController.text = result.merchant;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-detected ${result.detectedApp} payment: ₹${result.amount.toStringAsFixed(0)}'),
              duration: const Duration(seconds: 4),
            ),
          );
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
    super.dispose();
  }

  void _showSMSAutoFillDialog() {
    final smsController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.sms_outlined, color: Color(0xFF6C5CE7)),
              SizedBox(width: 8),
              Text('Auto-Detect Bank SMS'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste bank SMS or payment alert text below to automatically extract amount, category, & payment method:',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: smsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Rs 450.00 debited for Swiggy Food via UPI...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Quick Test Payment App & Bank Presets:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildPresetBadge('GPay (₹350 Food)', () {
                      smsController.text = 'Paid Rs 350.00 to Starbucks via Google Pay GPay UPI from HDFC Bank.';
                    }),
                    _buildPresetBadge('PhonePe (₹1,250 Grocery)', () {
                      smsController.text = 'Paid Rs 1,250.00 to Blinkit Supermarket via PhonePe UPI.';
                    }),
                    _buildPresetBadge('Paytm (₹4,500 Shopping)', () {
                      smsController.text = 'Rs 4,500.00 debited for Amazon Order via Paytm UPI.';
                    }),
                    _buildPresetBadge('CRED (₹2,800 Bill)', () {
                      smsController.text = 'Paid Rs 2,800.00 for Electricity Bill payment using CRED UPI.';
                    }),
                    _buildPresetBadge('Salary (₹50,000)', () {
                      smsController.text = 'Rs 50,000.00 credited to Bank A/C XX1234 for Salary Deposit via Bank Transfer.';
                    }),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final result = SMSParserService.parseSMS(smsController.text);
                if (result != null) {
                  setState(() {
                    _amountController.text = result.amount.toStringAsFixed(0);
                    _isExpense = result.type == TransactionType.expense;
                    _selectedCategory = result.category;
                    _selectedPaymentMethod = result.paymentMethod;
                    _descriptionController.text = result.merchant;
                  });
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Detected from ${result.detectedApp}: ₹${result.amount.toStringAsFixed(0)} (${result.category})')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not parse SMS amount. Check message format.')),
                  );
                }
              },
              child: const Text('Auto-Fill Entry'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPresetBadge(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ),
    );
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

      // If Credit Card was chosen and user picked a card (or cards exist), append card last4 tag
      if (_selectedPaymentMethod == 'Credit Card') {
        final rawCards = LocalStorageService.getCreditCards();
        final effectiveLast4 = _selectedCardLast4 ?? (rawCards.isNotEmpty ? (rawCards.first['last4'] as String?) : null);
        if (effectiveLast4 != null && effectiveLast4.isNotEmpty && !finalDesc.contains('••')) {
          finalDesc = finalDesc.isEmpty ? 'Credit Card ••$effectiveLast4' : '$finalDesc (Card ••$effectiveLast4)';
        }
      }

      final transaction = TransactionModel(
        id: widget.transactionToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        uid: widget.transactionToEdit?.uid ?? activeUid,
        type: _isExpense ? TransactionType.expense : TransactionType.income,
        amount: amount,
        category: saveCategory,
        paymentMethod: _selectedPaymentMethod,
        description: finalDesc,
        receiptPath: _receiptPath,
        date: _selectedDate,
        isRecurring: _isRecurring,
      );

      // Save the transaction — the Hive box watcher in TransactionProvider
      // automatically triggers loadTransactions() + notifyListeners() on every
      // write, so all screens (Dashboard, Analytics, Budget) refresh in real-time.
      if (widget.transactionToEdit == null) {
        await txProvider.addTransaction(transaction);
      } else {
        await txProvider.updateTransaction(transaction);
      }

      if (!mounted) return;

      // Pop back first so the notification appears over the home/list screen.
      Navigator.pop(context);

      // Show the premium floating notification on the parent screen.
      if (context.mounted) {
        final currency = Provider.of<ThemeCurrencyProvider>(context, listen: false).currency;
        final isEditing = widget.transactionToEdit != null;
        TransactionNotification.show(
          context,
          title: isEditing
              ? (_isExpense ? 'Expense Updated' : 'Income Updated')
              : (_isExpense ? 'Expense Added' : 'Income Added'),
          amount: amount.toStringAsFixed(0),
          category: saveCategory,
          currency: currency,
          type: _isExpense
              ? TransactionNotificationType.expense
              : TransactionNotificationType.income,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : _selectedPaymentMethod,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transactionToEdit != null
              ? 'Edit Transaction'
              : (_isExpense ? 'Add Expense' : 'Add Income'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sms_outlined),
            onPressed: _showSMSAutoFillDialog,
            tooltip: 'Auto-Detect Bank SMS',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Selector Toggle Buttons
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
                          color: _isExpense ? const Color(0xFFFF7675) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Expense',
                          style: TextStyle(
                            color: _isExpense ? Colors.white : Colors.black87,
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
                          color: !_isExpense ? const Color(0xFF00B894) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Income',
                          style: TextStyle(
                            color: !_isExpense ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Amount Input Field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$currency ',
                  prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter amount';
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) return 'Please enter valid number';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Category Selector & Smart Suggestions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  if (_autoDetectedCategory != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF6C5CE7)),
                          const SizedBox(width: 4),
                          Text(
                            'Smart AI: $_autoDetectedCategory',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: ValueKey('cat_${_isExpense}_$currentCategory'),
                initialValue: currentCategory,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6C5CE7), size: 20),
                  labelText: 'Selected Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: filteredCategories.map((cat) {
                  return DropdownMenuItem(
                    value: cat.name,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CategoryIconWidget(
                          category: cat,
                          size: 28,
                          iconSize: 14,
                          showTypeBadge: true,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            cat.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                      _autoDetectedCategory = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),

              // Smart Category Chips
              Builder(
                builder: (context) {
                  final suggested = SmartCategorizerService.getSuggestedCategories(
                    _descriptionController.text,
                    isExpense: _isExpense,
                  );
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: suggested.map((catName) {
                        final isSel = currentCategory == catName;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: isSel
                                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                : const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFF6C5CE7)),
                            label: Text(catName),
                            onPressed: () {
                              setState(() {
                                _selectedCategory = catName;
                                _autoDetectedCategory = null;
                              });
                            },
                            backgroundColor: isSel
                                ? const Color(0xFF6C5CE7)
                                : const Color(0xFF6C5CE7).withValues(alpha: 0.08),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              color: isSel ? Colors.white : const Color(0xFF2D3436),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSel ? const Color(0xFF6C5CE7) : const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Payment Method Selector
              DropdownButtonFormField<String>(
                key: ValueKey('pm_$currentPaymentMethod'),
                initialValue: currentPaymentMethod,
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: AppConstants.paymentMethods.map((method) {
                  return DropdownMenuItem(value: method, child: Text(method));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPaymentMethod = val);
                },
              ),
              const SizedBox(height: 20),

              // Specific Credit Card Picker (if paymentMethod == 'Credit Card')
              if (_selectedPaymentMethod == 'Credit Card') ...[
                _buildCreditCardPicker(),
                const SizedBox(height: 20),
              ],

              // Date & Time Picker Tile
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, color: Color(0xFF6C5CE7)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Date & Time', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            Formatters.formatShortDateTime(_selectedDate),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_calendar_outlined, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Description / Notes Field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Notes / Description (Optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isExpense ? const Color(0xFFFF7675) : const Color(0xFF00B894),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    widget.transactionToEdit != null
                        ? 'Update Transaction'
                        : (_isExpense ? 'Save Expense' : 'Save Income'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a credit card selector dropdown populated with user's saved cards.
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
        child: Row(
          children: const [
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
