import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../services/local_storage_service.dart';

class CategoryProvider extends ChangeNotifier {
  List<CategoryModel> _categories = [];
  String? _activeUid;

  List<CategoryModel> get categories => _categories;
  List<CategoryModel> get expenseCategories => _categories.where((c) => !c.isIncome).toList();
  List<CategoryModel> get incomeCategories => _categories.where((c) => c.isIncome).toList();

  CategoryProvider() {
    loadCategories();
  }

  void loadForUser(String? uid) {
    if (_activeUid != uid) {
      _activeUid = uid;
      loadCategories();
    }
  }

  void loadCategories() {
    _categories = LocalStorageService.getCategories(uid: _activeUid);
    notifyListeners();
  }

  Future<void> addCategory(CategoryModel category) async {
    await LocalStorageService.saveCategory(category);
    loadCategories();
  }

  Future<void> updateCategory(CategoryModel category) async {
    await LocalStorageService.saveCategory(category);
    loadCategories();
  }

  Future<void> deleteCategory(String id) async {
    await LocalStorageService.deleteCategory(id);
    loadCategories();
  }
}
