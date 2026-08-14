import 'dart:convert';
import 'package:crypto/crypto.dart';
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
  static const String usersBoxName = 'pocketify_users';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(transactionsBoxName);
    await Hive.openBox(categoriesBoxName);
    await Hive.openBox(budgetsBoxName);
    await Hive.openBox(savingsBoxName);
    await Hive.openBox(settingsBoxName);
    await Hive.openBox(usersBoxName);

    // Always upsert system default categories by their fixed IDs.
    // This ensures newly added defaults (e.g., new income categories) appear
    // on existing installs without wiping user-created custom categories.
    final categoriesBox = Hive.box(categoriesBoxName);

    // Remove legacy default income categories if present
    await categoriesBox.delete('cat_business');
    await categoriesBox.delete('cat_freelance');
    await categoriesBox.delete('cat_rental');

    for (final cat in AppConstants.defaultCategories) {
      if (!categoriesBox.containsKey(cat.id)) {
        await categoriesBox.put(cat.id, cat.toMap());
      } else {
        final existingMap = Map<dynamic, dynamic>.from(categoriesBox.get(cat.id));
        existingMap['iconCodePoint'] = cat.iconCodePoint;
        existingMap['colorValue'] = cat.colorValue;
        existingMap['isIncome'] = cat.isIncome;
        if (!existingMap.containsKey('deductFromBudget')) {
          existingMap['deductFromBudget'] = cat.deductFromBudget;
        }
        await categoriesBox.put(cat.id, existingMap);
      }
    }

    // Seed default guest user account for Quick Guest Login & session restore
    final usersBox = Hive.box(usersBoxName);
    if (!usersBox.containsKey('alex@pocketify.app')) {
      final bytes = utf8.encode('123456pocketify_salt_2024');
      final hash = sha256.convert(bytes).toString();
      await usersBox.put('alex@pocketify.app', {
        'uid': 'user_guest',
        'name': 'Alex',
        'email': 'alex@pocketify.app',
        'passwordHash': hash,
      });
    }
  }

  // --- User-Scoped Transactions ---
  static List<TransactionModel> getTransactions({String? uid}) {
    final box = Hive.box(transactionsBoxName);
    return box.values
        .map((e) => TransactionModel.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();
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
    return box.values
        .map((e) => CategoryModel.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();
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
    return box.values
        .map((e) => BudgetModel.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();
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
    return box.values
        .map((e) => SavingsGoalModel.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  static Future<void> saveSavingsGoal(SavingsGoalModel goal) async {
    final box = Hive.box(savingsBoxName);
    await box.put(goal.id, goal.toMap());
  }

  static Future<void> deleteSavingsGoal(String id) async {
    final box = Hive.box(savingsBoxName);
    await box.delete(id);
  }

  // --- Local User Accounts (replaces Firebase Auth) ---

  /// Retrieve an account map by email key. Returns null if not found.
  static Map<String, dynamic>? getAccount(String email) {
    final box = Hive.box(usersBoxName);
    final raw = box.get(email.toLowerCase());
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }

  /// Save (create or update) an account keyed by email.
  static Future<void> saveAccount(Map<String, dynamic> account) async {
    final box = Hive.box(usersBoxName);
    final email = (account['email'] as String).toLowerCase();
    await box.put(email, account);
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

  // --- New Month Budget Prompt Tracking ---
  static String? getLastBudgetPromptMonth() {
    final box = Hive.box(settingsBoxName);
    return box.get('last_budget_prompt_month') as String?;
  }

  static Future<void> setLastBudgetPromptMonth(String monthKey) async {
    final box = Hive.box(settingsBoxName);
    await box.put('last_budget_prompt_month', monthKey);
  }

  // --- Auto Monthly Report Shown Tracking ---
  /// Returns the month-key ("yyyy-MM") for which the auto report was last shown.
  static String? getLastMonthReportShownMonth() {
    final box = Hive.box(settingsBoxName);
    return box.get('last_month_report_shown') as String?;
  }

  /// Persist the month-key so the auto report is not shown again this month.
  static Future<void> setLastMonthReportShownMonth(String monthKey) async {
    final box = Hive.box(settingsBoxName);
    await box.put('last_month_report_shown', monthKey);
  }

  // --- Biometric / PIN Lock ---

  /// Returns true if the user has enabled biometric/PIN lock.
  static bool getBiometricEnabled() {
    final box = Hive.box(settingsBoxName);
    return box.get('biometric_enabled', defaultValue: false) as bool;
  }

  /// Persists the biometric lock preference.
  static Future<void> setBiometricEnabled(bool enabled) async {
    final box = Hive.box(settingsBoxName);
    await box.put('biometric_enabled', enabled);
  }

  // --- SMS Auto Capture Preference ---

  /// Returns true if user enabled SMS auto-capture.
  static bool getSmsAutoCaptureEnabled() {
    final box = Hive.box(settingsBoxName);
    return box.get('sms_auto_capture_enabled', defaultValue: true) as bool;
  }

  /// Persists SMS auto-capture preference.
  static Future<void> setSmsAutoCaptureEnabled(bool enabled) async {
    final box = Hive.box(settingsBoxName);
    await box.put('sms_auto_capture_enabled', enabled);
  }

  // --- Duplicate Protection Mode & Time Window Preferences ---
  // Modes: 'smart' (Default), 'allow_all', 'flag_review'

  static String getDuplicateMode() {
    final box = Hive.box(settingsBoxName);
    return box.get('duplicate_mode', defaultValue: 'smart') as String;
  }

  static Future<void> setDuplicateMode(String mode) async {
    final box = Hive.box(settingsBoxName);
    await box.put('duplicate_mode', mode);
  }

  /// Returns the time window in minutes for duplicate SMS detection (default: 1 minute).
  static int getDeduplicationWindowMinutes() {
    final box = Hive.box(settingsBoxName);
    return box.get('deduplication_window_minutes', defaultValue: 1) as int;
  }

  /// Persists the custom deduplication time window in minutes.
  static Future<void> setDeduplicationWindowMinutes(int minutes) async {
    final box = Hive.box(settingsBoxName);
    await box.put('deduplication_window_minutes', minutes);
  }

  // --- SMS Interception & Processing Logs ---

  static List<Map<String, dynamic>> getSmsCaptureLogs() {
    final box = Hive.box(settingsBoxName);
    final raw = box.get('sms_capture_logs');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  static Future<void> addSmsCaptureLog(Map<String, dynamic> entry) async {
    final box = Hive.box(settingsBoxName);
    final logs = getSmsCaptureLogs();
    // Prepend new entry
    logs.insert(0, entry);
    // Keep max 80 recent logs to keep storage lightweight
    if (logs.length > 80) {
      logs.removeRange(80, logs.length);
    }
    await box.put('sms_capture_logs', logs);
  }

  static Future<void> clearSmsCaptureLogs() async {
    final box = Hive.box(settingsBoxName);
    await box.delete('sms_capture_logs');
  }
}
