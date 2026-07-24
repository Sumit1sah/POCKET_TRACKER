import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

class ThemeCurrencyProvider extends ChangeNotifier {
  String _currency = '₹';
  bool _isDarkMode = false;

  String get currency => _currency;
  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeCurrencyProvider() {
    _currency = LocalStorageService.getCurrency();
    _isDarkMode = LocalStorageService.isDarkMode();
  }

  Future<void> setCurrency(String newCurrency) async {
    _currency = newCurrency;
    await LocalStorageService.setCurrency(newCurrency);
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    await LocalStorageService.setDarkMode(isDark);
    notifyListeners();
  }
}
