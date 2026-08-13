import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../models/user_profile_model.dart';
import '../services/local_storage_service.dart';

/// Manages authentication state using local Hive storage only.
///
/// - Accounts are stored in Hive (offline, no internet required).
/// - Passwords are hashed with SHA-256 before storage.
/// - Session is persisted via [LocalStorageService.getCurrentUser()].
class AuthProvider extends ChangeNotifier {
  UserProfileModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserProfileModel? get currentUser => _currentUser;

  AuthProvider() {
    // Restore session from Hive on startup (fallback to Alex guest account if null)
    _currentUser = LocalStorageService.getCurrentUser() ??
        UserProfileModel(
          uid: 'user_guest',
          name: 'Alex',
          email: 'alex@pocketify.app',
        );
  }

  // ── Password hashing ──────────────────────────────────────────────────────

  static String _hashPassword(String password) {
    final bytes = utf8.encode('${password}pocketify_salt_2024');
    return sha256.convert(bytes).toString();
  }

  // ── Public auth actions ───────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300)); // slight delay for UX

    final account = LocalStorageService.getAccount(email.trim().toLowerCase());

    if (account == null) {
      _errorMessage = 'No account found with this email.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final hash = _hashPassword(password);
    if (account['passwordHash'] != hash) {
      _errorMessage = 'Incorrect email or password.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final user = UserProfileModel(
      uid: account['uid'] as String,
      name: account['name'] as String,
      email: account['email'] as String,
    );

    _currentUser = user;
    await LocalStorageService.saveCurrentUser(user);

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    final emailKey = email.trim().toLowerCase();

    // Check if account already exists
    if (LocalStorageService.getAccount(emailKey) != null) {
      _errorMessage = 'An account with this email already exists.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Generate a local UID
    final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final hash = _hashPassword(password);

    await LocalStorageService.saveAccount({
      'uid': uid,
      'name': name.trim(),
      'email': emailKey,
      'passwordHash': hash,
    });

    final user = UserProfileModel(
      uid: uid,
      name: name.trim(),
      email: emailKey,
    );

    _currentUser = user;
    await LocalStorageService.saveCurrentUser(user);

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> updateProfileDetails(String newName, String newEmail) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    notifyListeners();

    final updatedUser = UserProfileModel(
      uid: _currentUser!.uid,
      name: newName.trim(),
      email: newEmail.trim().toLowerCase(),
      photoUrl: _currentUser!.photoUrl,
      currency: _currentUser!.currency,
      isDarkMode: _currentUser!.isDarkMode,
    );

    _currentUser = updatedUser;
    await LocalStorageService.saveCurrentUser(updatedUser);

    // Update stored account email/name
    final account = LocalStorageService.getAccount(_currentUser!.email);
    if (account != null) {
      final updated = Map<String, dynamic>.from(account);
      updated['name'] = newName.trim();
      updated['email'] = newEmail.trim().toLowerCase();
      await LocalStorageService.saveAccount(updated);
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final account = LocalStorageService.getAccount(_currentUser!.email);
    if (account == null) {
      _errorMessage = 'Account not found.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final currentHash = _hashPassword(currentPassword);
    if (account['passwordHash'] != currentHash) {
      _errorMessage = 'Current password is incorrect.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final updated = Map<String, dynamic>.from(account);
    updated['passwordHash'] = _hashPassword(newPassword);
    await LocalStorageService.saveAccount(updated);

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _currentUser = null;
    await LocalStorageService.clearCurrentUser();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
