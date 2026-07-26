import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../models/budget_model.dart';
import '../models/savings_goal_model.dart';
import '../models/user_profile_model.dart';
import '../utils/constants.dart';

class LocalStorageService {
  static const String transactionsBoxName = 'pocketify_transactions';
  static const String categoriesBoxName = 'pocketify_categories';
  static const String budgetsBoxName = 'pocketify_budgets';
  static const String savingsBoxName = 'pocketify_savings';
  static const String settingsBoxName = 'pocketify_settings';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(transactionsBoxName);
    await Hive.openBox(categoriesBoxName);
    await Hive.openBox(budgetsBoxName);
    await Hive.openBox(savingsBoxName);
    await Hive.openBox(settingsBoxName);

    // Always upsert system default categories by their fixed IDs.
    // This ensures newly added defaults (e.g., new income categories) appear
    // on existing installs without wiping user-created custom categories.
    final categoriesBox = Hive.box(categoriesBoxName);
    for (final cat in AppConstants.defaultCategories) {
      if (!categoriesBox.containsKey(cat.id)) {
        await categoriesBox.put(cat.id, cat.toMap());
      }
    }
  }

  // --- User-Scoped Transactions ---
  static List<TransactionModel> getTransactions({String? uid}) {
    final box = Hive.box(transactionsBoxName);
    final all = box.values
        .map((e) => TransactionModel.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();

    if (uid == null || uid.isEmpty || uid == 'all') return all;
    return all.where((t) => t.uid == uid || t.uid == 'local_user').toList();
  }

  static Future<void> saveTransaction(TransactionModel transaction) async {
    final box = Hive.box(transactionsBoxName);
    await box.put(transaction.id, transaction.toMap());
  }

  static Future<void> deleteTransaction(String id) async {
    final box = Hive.box(transactionsBoxName);
    await box.delete(id);
  }

  // --- User-Scoped Categories ---
  static List<CategoryModel> getCategories({String? uid}) {
    final box = Hive.box(categoriesBoxName);
    final all = box.values
        .map((e) => CategoryModel.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();

    if (uid == null || uid.isEmpty) return all;
    return all.where((c) => c.uid == uid || c.isDefault || c.uid == 'system').toList();
  }

  static Future<void> saveCategory(CategoryModel category) async {
    final box = Hive.box(categoriesBoxName);
    await box.put(category.id, category.toMap());
  }

  static Future<void> deleteCategory(String id) async {
    final box = Hive.box(categoriesBoxName);
    await box.delete(id);
  }

  // --- User-Scoped Budgets ---
  static List<BudgetModel> getBudgets({String? uid}) {
    final box = Hive.box(budgetsBoxName);
    final all = box.values
        .map((e) => BudgetModel.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();

    if (uid == null || uid.isEmpty) return all;
    return all.where((b) => b.uid == uid).toList();
  }

  static Future<void> saveBudget(BudgetModel budget) async {
    final box = Hive.box(budgetsBoxName);
    await box.put(budget.id, budget.toMap());
  }

  static Future<void> deleteBudget(String id) async {
    final box = Hive.box(budgetsBoxName);
    await box.delete(id);
  }

  // --- User-Scoped Savings Goals ---
  static List<SavingsGoalModel> getSavingsGoals({String? uid}) {
    final box = Hive.box(savingsBoxName);
    final all = box.values
        .map((e) => SavingsGoalModel.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();

    if (uid == null || uid.isEmpty) return all;
    return all.where((g) => g.uid == uid).toList();
  }

  static Future<void> saveSavingsGoal(SavingsGoalModel goal) async {
    final box = Hive.box(savingsBoxName);
    await box.put(goal.id, goal.toMap());
  }

  static Future<void> deleteSavingsGoal(String id) async {
    final box = Hive.box(savingsBoxName);
    await box.delete(id);
  }

  // --- Settings & Persistent User Session ---
  static UserProfileModel? getCurrentUser() {
    final box = Hive.box(settingsBoxName);
    final map = box.get('current_user');
    if (map != null) {
      return UserProfileModel.fromMap(Map<dynamic, dynamic>.from(map));
    }
    return null;
  }

  static Future<void> saveCurrentUser(UserProfileModel user) async {
    final box = Hive.box(settingsBoxName);
    await box.put('current_user', user.toMap());
  }

  static Future<void> clearCurrentUser() async {
    final box = Hive.box(settingsBoxName);
    await box.delete('current_user');
  }

  static String getCurrency() {
    final box = Hive.box(settingsBoxName);
    return box.get('currency', defaultValue: '₹');
  }

  static Future<void> setCurrency(String currency) async {
    final box = Hive.box(settingsBoxName);
    await box.put('currency', currency);
  }

  static bool isDarkMode() {
    final box = Hive.box(settingsBoxName);
    return box.get('isDarkMode', defaultValue: false);
  }

  static Future<void> setDarkMode(bool isDark) async {
    final box = Hive.box(settingsBoxName);
    await box.put('isDarkMode', isDark);
  }

  // --- Credit Cards ---
  static List<Map<String, dynamic>> getCreditCards() {
    final box = Hive.box(settingsBoxName);
    final raw = box.get('credit_cards');
    if (raw == null) return [];
    final list = List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e)),
    );
    // Strict rule: One user can have ONLY ONE credit card
    return list.take(1).toList();
  }

  static Future<void> saveCreditCard(Map<String, dynamic> card) async {
    final box = Hive.box(settingsBoxName);
    final cards = getCreditCards();
    final idx = cards.indexWhere((c) => c['id'] == card['id']);
    if (idx >= 0) {
      cards[idx] = card;
    } else {
      // One user can add ONE credit card only. Replace existing card if present.
      if (cards.isNotEmpty) {
        cards[0] = card;
      } else {
        cards.add(card);
      }
    }
    await box.put('credit_cards', cards);
  }

  static Future<void> deleteCreditCard(String id) async {
    final box = Hive.box(settingsBoxName);
    final cards = getCreditCards();
    cards.removeWhere((c) => c['id'] == id);
    await box.put('credit_cards', cards);
  }

  // --- Credit Card Preference (onboarding question) ---

  /// Returns true if user said they have a CC, false if they said no,
  /// and null if the question hasn't been asked yet.
  static bool? getCCPreference() {
    final box = Hive.box(settingsBoxName);
    final raw = box.get('cc_preference');
    if (raw == null) return null;
    return raw as bool;
  }

  /// Whether the "do you have a credit card?" question has been shown.
  static bool isCCPreferenceSet() => getCCPreference() != null;

  /// Save the user's answer. true = has CC, false = no CC.
  static Future<void> setCCPreference(bool hasCreditCard) async {
    final box = Hive.box(settingsBoxName);
    await box.put('cc_preference', hasCreditCard);
  }
}
