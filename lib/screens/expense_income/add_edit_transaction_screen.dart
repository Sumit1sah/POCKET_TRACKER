import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../services/sms_parser_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

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
  DateTime _selectedDate = DateTime.now();
  String? _receiptPath;
  bool _isRecurring = false;

  @override
  void initState() {
    super.initState();
    _isExpense = widget.isExpense;
    final edit = widget.transactionToEdit;
    _amountController = TextEditingController(text: edit != null ? edit.amount.toStringAsFixed(0) : '');
    _descriptionController = TextEditingController(text: edit?.description ?? '');
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
      final matchingCategories = categories.where((c) => c.isIncome == !_isExpense).toList();
      final filteredCategories = matchingCategories.isNotEmpty ? matchingCategories : categories;

      final saveCategory = filteredCategories.any((c) => c.name == _selectedCategory)
          ? _selectedCategory
          : (filteredCategories.isNotEmpty ? filteredCategories.first.name : 'Food');

      final transaction = TransactionModel(
        id: widget.transactionToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        uid: widget.transactionToEdit?.uid ?? activeUid,
        type: _isExpense ? TransactionType.expense : TransactionType.income,
        amount: amount,
        category: saveCategory,
        paymentMethod: _selectedPaymentMethod,
        description: _descriptionController.text.trim(),
        receiptPath: _receiptPath,
        date: _selectedDate,
        isRecurring: _isRecurring,
      );

      // Await the save so that notifyListeners() fires BEFORE we pop back,
      // ensuring Analytics, Dashboard, and all Provider listeners get fresh data.
      if (widget.transactionToEdit == null) {
        await txProvider.addTransaction(transaction);
      } else {
        await txProvider.updateTransaction(transaction);
      }

      // Explicitly reload to guarantee all screens (Analytics, Budget, etc.) refresh.
      txProvider.loadTransactions();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isExpense
              ? 'Expense of ₹${amount.toStringAsFixed(0)} saved successfully!'
              : 'Income of ₹${amount.toStringAsFixed(0)} saved successfully!'),
          backgroundColor: _isExpense ? const Color(0xFFFF7675) : const Color(0xFF00B894),
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;
    final rawCategories = Provider.of<CategoryProvider>(context).categories;
    final categories = rawCategories.isNotEmpty ? rawCategories : AppConstants.defaultCategories;

    final matchingCategories = categories.where((c) => c.isIncome == !_isExpense).toList();
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

              // Category Selector
              DropdownButtonFormField<String>(
                key: ValueKey('cat_${_isExpense}_$currentCategory'),
                initialValue: currentCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: filteredCategories.map((cat) {
                  return DropdownMenuItem(
                    value: cat.name,
                    child: Text(cat.name),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 20),

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
}
