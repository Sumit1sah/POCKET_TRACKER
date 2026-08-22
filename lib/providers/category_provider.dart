import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../services/local_storage_service.dart';
import '../utils/constants.dart';

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
    LocalStorageService.deleteCategory('cat_ecommerce');
    LocalStorageService.deleteCategory('cat_auto_bus');
    var loaded = LocalStorageService.getCategories(uid: _activeUid);
    if (loaded.isEmpty) {
      _categories = List.from(AppConstants.defaultCategories);
    } else {
      final existingIds = loaded.map((c) => c.id).toSet();
      final missingDefaults = AppConstants.defaultCategories
          .where((d) => !existingIds.contains(d.id))
          .toList();
      if (missingDefaults.isNotEmpty) {
        for (final m in missingDefaults) {
          LocalStorageService.saveCategory(m);
        }
        loaded = LocalStorageService.getCategories(uid: _activeUid);
      }
      _categories = loaded;
    }
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
