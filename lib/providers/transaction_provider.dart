import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/local_storage_service.dart';

class TransactionProvider extends ChangeNotifier {
  List<TransactionModel> _transactions = [];
  String? _activeUid;
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';
  String _selectedPaymentMethodFilter = 'All';
  DateTimeRange? _selectedDateRange;

  List<TransactionModel> get transactions => _transactions;

  TransactionProvider() {
    loadTransactions();
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

  double get netBalance => totalIncome - totalExpense;

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
