import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction_model.dart';
import '../services/local_storage_service.dart';

class TransactionProvider extends ChangeNotifier {
  List<TransactionModel> _transactions = [];
  String? _activeUid;
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';
  String _selectedPaymentMethodFilter = 'All';
  DateTimeRange? _selectedDateRange;

  /// Stream subscription that watches the Hive box for any external writes
  /// (e.g., SMS auto-capture, background isolate) and auto-refreshes the UI.
  StreamSubscription? _hiveBoxSubscription;

  List<TransactionModel> get transactions => _transactions;

  TransactionProvider() {
    loadTransactions();
    _subscribeToHiveBox();
  }

  /// Subscribe to Hive box changes so any write — from this provider, from
  /// SmsAutoCaptureService, or any other source — triggers a live UI refresh.
  void _subscribeToHiveBox() {
    final box = Hive.box(LocalStorageService.transactionsBoxName);
    _hiveBoxSubscription = box.watch().listen((_) {
      loadTransactions();
    });
  }

  void loadForUser(String? uid) {
    _activeUid = uid;
    loadTransactions();
  }

  void loadTransactions() {
    _transactions = LocalStorageService.getTransactions(uid: _activeUid);
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  @override
  void dispose() {
    _hiveBoxSubscription?.cancel();
    super.dispose();
  }

  double get totalIncome {
    return _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpense {
    return _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Total Credit Limit across registered credit cards as explicitly set by the user.
  double get totalCreditLimit {
    final cards = LocalStorageService.getCreditCards();
    return cards.fold(0.0, (sum, c) => sum + (c['limit'] as num? ?? 0.0).toDouble());
  }

  /// Total Net Balance = Income + Total Credit Limit - Total Expense.
  /// Adding total credit limit ensures credit card debits transparently deduct
  /// from the overall net balance while accurately representing total financial capacity.
  double get netBalance => totalIncome + totalCreditLimit - totalExpense;

  // ── Credit Card Analytics ────────────────────────────────────────────────

  /// CC expense transactions this month (purchases, charges).
  List<TransactionModel> get creditCardTransactions {
    final now = DateTime.now();
    return _transactions.where((t) =>
      t.type == TransactionType.expense &&
      t.paymentMethod == 'Credit Card' &&
      t.date.year == now.year &&
      t.date.month == now.month,
    ).toList();
  }

  /// CC refund transactions this month — income credited BACK to the credit
  /// card (e.g. Flipkart/Amazon returns). These reduce the card's spent total.
  List<TransactionModel> get creditCardRefundTransactions {
    final now = DateTime.now();
    return _transactions.where((t) =>
      t.type == TransactionType.income &&
      t.paymentMethod == 'Credit Card' &&
      t.date.year == now.year &&
      t.date.month == now.month,
    ).toList();
  }

  /// Net spent via credit card this month = purchases − refunds (≥ 0).
  double get totalCreditCardSpent {
    final purchases =
        creditCardTransactions.fold(0.0, (s, t) => s + t.amount);
    final refunds =
        creditCardRefundTransactions.fold(0.0, (s, t) => s + t.amount);
    return (purchases - refunds).clamp(0.0, double.infinity);
  }

  /// Extracts the card identifier (e.g. "••2235") from a transaction's
  /// description. Used by both expense and refund grouping.
  String _extractCardKey(TransactionModel t) {
    // Match masked number: ••XXXX or ****XXXX
    final maskedMatch =
        RegExp(r'[•\*]{1,4}(\d{4})').firstMatch(t.description);
    if (maskedMatch != null) return '••${maskedMatch.group(1)}';

    // Match plain 4-digit card number
    final plain4Match = RegExp(r'\b(\d{4})\b').firstMatch(t.description);
    if (plain4Match != null) return '••${plain4Match.group(1)}';

    return 'Credit Card';
  }

  /// Per-card NET spending map (expenses − refunds) keyed by card identifier.
  /// A card with more refunds than purchases shows 0 (never negative).
  Map<String, double> get creditCardSpendingByCard {
    final map = <String, double>{};

    // Add purchase amounts
    for (final t in creditCardTransactions) {
      final key = _extractCardKey(t);
      map[key] = (map[key] ?? 0.0) + t.amount;
    }

    // Subtract refund amounts — money returned to the CC reduces the balance
    for (final t in creditCardRefundTransactions) {
      final key = _extractCardKey(t);
      map[key] = (map[key] ?? 0.0) - t.amount;
      // Clamp: a card cannot show negative net spent
      if (map[key]! < 0) map[key] = 0.0;
    }

    return map;
  }

  List<TransactionModel> get filteredTransactions {
    return _transactions.where((t) {
      final matchesQuery = _searchQuery.isEmpty ||
          t.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.amount.toString().contains(_searchQuery);

      final matchesCategory = _selectedCategoryFilter == 'All' || t.category == _selectedCategoryFilter;
      final matchesPayment = _selectedPaymentMethodFilter == 'All' || t.paymentMethod == _selectedPaymentMethodFilter;
      final matchesDate = _selectedDateRange == null ||
          (t.date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
           t.date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1))));

      return matchesQuery && matchesCategory && matchesPayment && matchesDate;
    }).toList();
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    final scopedTransaction = transaction.copyWith(
      uid: transaction.uid.isEmpty ? (_activeUid ?? 'local_user') : transaction.uid,
    );
    await LocalStorageService.saveTransaction(scopedTransaction);
    loadTransactions();
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    await LocalStorageService.saveTransaction(transaction);
    loadTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    await LocalStorageService.deleteTransaction(id);
    loadTransactions();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(String category) {
    _selectedCategoryFilter = category;
    notifyListeners();
  }

  void setPaymentFilter(String paymentMethod) {
    _selectedPaymentMethodFilter = paymentMethod;
    notifyListeners();
  }

  void setDateRange(DateTimeRange? range) {
    _selectedDateRange = range;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCategoryFilter = 'All';
    _selectedPaymentMethodFilter = 'All';
    _selectedDateRange = null;
    notifyListeners();
  }
}
