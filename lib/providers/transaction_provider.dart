import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction_model.dart';
import '../services/local_storage_service.dart';

enum TransactionTypeFilter { all, expense, income }
enum TransactionSortOrder { newest, oldest, amountHighToLow, amountLowToHigh }
enum DatePreset { allTime, today, thisWeek, thisMonth, lastMonth, custom }

class TransactionProvider extends ChangeNotifier {
  List<TransactionModel> _transactions = [];
  List<TransactionModel>? _filteredTransactionsCache;
  double? _totalIncomeCache;
  double? _totalExpenseCache;
  String? _activeUid;
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';
  String _selectedPaymentMethodFilter = 'All';
  DateTimeRange? _selectedDateRange;
  TransactionTypeFilter _typeFilter = TransactionTypeFilter.all;
  TransactionSortOrder _sortOrder = TransactionSortOrder.newest;
  DatePreset _datePreset = DatePreset.allTime;
  double? _minAmount;
  double? _maxAmount;

  /// Stream subscription that watches the Hive box for any external writes
  /// (e.g., SMS auto-capture, background isolate) and auto-refreshes the UI.
  StreamSubscription? _hiveBoxSubscription;

  List<TransactionModel> get transactions => _transactions;
  String get searchQuery => _searchQuery;
  String get selectedCategoryFilter => _selectedCategoryFilter;
  String get selectedPaymentMethodFilter => _selectedPaymentMethodFilter;
  DateTimeRange? get selectedDateRange => _selectedDateRange;
  TransactionTypeFilter get typeFilter => _typeFilter;
  TransactionSortOrder get sortOrder => _sortOrder;
  DatePreset get datePreset => _datePreset;
  double? get minAmount => _minAmount;
  double? get maxAmount => _maxAmount;

  int get activeFilterCount {
    int count = 0;
    if (_searchQuery.isNotEmpty) count++;
    if (_selectedCategoryFilter != 'All') count++;
    if (_selectedPaymentMethodFilter != 'All') count++;
    if (_typeFilter != TransactionTypeFilter.all) count++;
    if (_datePreset != DatePreset.allTime || _selectedDateRange != null) count++;
    if (_minAmount != null || _maxAmount != null) count++;
    if (_sortOrder != TransactionSortOrder.newest) count++;
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0;

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
    if (_activeUid != uid) {
      _activeUid = uid;
      loadTransactions();
    }
  }

  void loadTransactions() {
    _transactions = LocalStorageService.getTransactions(uid: _activeUid);
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    _invalidateCaches();
    notifyListeners();
  }

  void _invalidateCaches() {
    _filteredTransactionsCache = null;
    _totalIncomeCache = null;
    _totalExpenseCache = null;
  }

  @override
  void dispose() {
    _hiveBoxSubscription?.cancel();
    super.dispose();
  }

  double get totalIncome {
    if (_totalIncomeCache == null) {
      double sum = 0.0;
      for (final t in _transactions) {
        if (t.type == TransactionType.income) sum += t.amount;
      }
      _totalIncomeCache = sum;
    }
    return _totalIncomeCache!;
  }

  double get totalExpense {
    if (_totalExpenseCache == null) {
      double sum = 0.0;
      for (final t in _transactions) {
        if (t.type == TransactionType.expense) sum += t.amount;
      }
      _totalExpenseCache = sum;
    }
    return _totalExpenseCache!;
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
    final maskedMatch =
        RegExp(r'[•\*]{1,4}(\d{4})').firstMatch(t.description);
    if (maskedMatch != null) return '••${maskedMatch.group(1)}';

    final plain4Match = RegExp(r'\b(\d{4})\b').firstMatch(t.description);
    if (plain4Match != null) return '••${plain4Match.group(1)}';

    return 'Credit Card';
  }

  /// Per-card NET spending map (expenses − refunds) keyed by card identifier.
  /// A card with more refunds than purchases shows 0 (never negative).
  Map<String, double> get creditCardSpendingByCard {
    final map = <String, double>{};

    for (final t in creditCardTransactions) {
      final key = _extractCardKey(t);
      map[key] = (map[key] ?? 0.0) + t.amount;
    }

    for (final t in creditCardRefundTransactions) {
      final key = _extractCardKey(t);
      map[key] = (map[key] ?? 0.0) - t.amount;
      if (map[key]! < 0) map[key] = 0.0;
    }

    return map;
  }

  double get filteredTotalExpense {
    return filteredTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get filteredTotalIncome {
    return filteredTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  List<TransactionModel> get filteredTransactions {
    if (_filteredTransactionsCache != null) return _filteredTransactionsCache!;

    final lowerQuery = _searchQuery.toLowerCase();
    final now = DateTime.now();

    List<TransactionModel> list = _transactions.where((t) {
      // 1. Search Query
      final matchesQuery = _searchQuery.isEmpty ||
          t.category.toLowerCase().contains(lowerQuery) ||
          t.description.toLowerCase().contains(lowerQuery) ||
          t.paymentMethod.toLowerCase().contains(lowerQuery) ||
          t.amount.toString().contains(_searchQuery);

      // 2. Type Filter (Expense / Income)
      bool matchesType = true;
      if (_typeFilter == TransactionTypeFilter.expense) {
        matchesType = t.type == TransactionType.expense;
      } else if (_typeFilter == TransactionTypeFilter.income) {
        matchesType = t.type == TransactionType.income;
      }

      // 3. Category Filter
      final matchesCategory = _selectedCategoryFilter == 'All' || t.category == _selectedCategoryFilter;

      // 4. Payment Method Filter
      final matchesPayment = _selectedPaymentMethodFilter == 'All' || t.paymentMethod == _selectedPaymentMethodFilter;

      // 5. Date Filter (Presets or Custom Range)
      bool matchesDate = true;
      if (_datePreset == DatePreset.today) {
        matchesDate = t.date.year == now.year && t.date.month == now.month && t.date.day == now.day;
      } else if (_datePreset == DatePreset.thisWeek) {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final firstDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        matchesDate = t.date.isAfter(firstDay.subtract(const Duration(seconds: 1)));
      } else if (_datePreset == DatePreset.thisMonth) {
        matchesDate = t.date.year == now.year && t.date.month == now.month;
      } else if (_datePreset == DatePreset.lastMonth) {
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        matchesDate = t.date.year == lastMonth.year && t.date.month == lastMonth.month;
      } else if (_selectedDateRange != null) {
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        matchesDate = t.date.isAfter(start.subtract(const Duration(seconds: 1))) && t.date.isBefore(end.add(const Duration(seconds: 1)));
      }

      // 6. Amount Range Filter
      bool matchesAmount = true;
      if (_minAmount != null && t.amount < _minAmount!) matchesAmount = false;
      if (_maxAmount != null && t.amount > _maxAmount!) matchesAmount = false;

      return matchesQuery && matchesType && matchesCategory && matchesPayment && matchesDate && matchesAmount;
    }).toList();

    // 7. Sorting Order
    switch (_sortOrder) {
      case TransactionSortOrder.newest:
        list.sort((a, b) => b.date.compareTo(a.date));
        break;
      case TransactionSortOrder.oldest:
        list.sort((a, b) => a.date.compareTo(b.date));
        break;
      case TransactionSortOrder.amountHighToLow:
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case TransactionSortOrder.amountLowToHigh:
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }

    _filteredTransactionsCache = list;
    return _filteredTransactionsCache!;
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    final scopedTransaction = transaction.copyWith(
      uid: transaction.uid.isEmpty ? (_activeUid ?? 'local_user') : transaction.uid,
    );
    await LocalStorageService.saveTransaction(scopedTransaction);
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    await LocalStorageService.saveTransaction(transaction);
  }

  Future<void> deleteTransaction(String id) async {
    await LocalStorageService.deleteTransaction(id);
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _filteredTransactionsCache = null;
      notifyListeners();
    }
  }

  void setTypeFilter(TransactionTypeFilter type) {
    if (_typeFilter != type) {
      _typeFilter = type;
      _filteredTransactionsCache = null;
      notifyListeners();
    }
  }

  void setCategoryFilter(String category) {
    if (_selectedCategoryFilter != category) {
      _selectedCategoryFilter = category;
      _filteredTransactionsCache = null;
      notifyListeners();
    }
  }

  void setPaymentFilter(String paymentMethod) {
    if (_selectedPaymentMethodFilter != paymentMethod) {
      _selectedPaymentMethodFilter = paymentMethod;
      _filteredTransactionsCache = null;
      notifyListeners();
    }
  }

  void setDatePreset(DatePreset preset, {DateTimeRange? customRange}) {
    _datePreset = preset;
    if (preset == DatePreset.custom) {
      _selectedDateRange = customRange;
    } else {
      _selectedDateRange = null;
    }
    _filteredTransactionsCache = null;
    notifyListeners();
  }

  void setDateRange(DateTimeRange? range) {
    _selectedDateRange = range;
    _datePreset = range != null ? DatePreset.custom : DatePreset.allTime;
    _filteredTransactionsCache = null;
    notifyListeners();
  }

  void setSortOrder(TransactionSortOrder sortOrder) {
    if (_sortOrder != sortOrder) {
      _sortOrder = sortOrder;
      _filteredTransactionsCache = null;
      notifyListeners();
    }
  }

  void setAmountRange(double? min, double? max) {
    _minAmount = min;
    _maxAmount = max;
    _filteredTransactionsCache = null;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCategoryFilter = 'All';
    _selectedPaymentMethodFilter = 'All';
    _selectedDateRange = null;
    _typeFilter = TransactionTypeFilter.all;
    _sortOrder = TransactionSortOrder.newest;
    _datePreset = DatePreset.allTime;
    _minAmount = null;
    _maxAmount = null;
    _filteredTransactionsCache = null;
    notifyListeners();
  }
}
