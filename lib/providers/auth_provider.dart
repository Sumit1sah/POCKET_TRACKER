import 'package:flutter/material.dart';
import '../models/user_profile_model.dart';
import '../services/local_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  UserProfileModel? _currentUser;

  bool get isAuthenticated => _currentUser != null;
  UserProfileModel? get currentUser => _currentUser;

  AuthProvider() {
    _loadSavedUserSession();
  }

  void _loadSavedUserSession() {
    _currentUser = LocalStorageService.getCurrentUser();
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final user = UserProfileModel(
      uid: 'user_${email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}',
      name: email.split('@').first,
      email: email,
    );
    _currentUser = user;
    await LocalStorageService.saveCurrentUser(user);
    notifyListeners();
    return true;
  }

  Future<bool> register(String name, String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final user = UserProfileModel(
      uid: 'user_${email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}',
      name: name,
      email: email,
    );
    _currentUser = user;
    await LocalStorageService.saveCurrentUser(user);
    notifyListeners();
    return true;
  }

  Future<bool> updateProfileDetails(String newName, String newEmail) async {
    if (_currentUser == null) return false;
    await Future.delayed(const Duration(milliseconds: 300));
    final updatedUser = UserProfileModel(
      uid: _currentUser!.uid,
      name: newName,
      email: newEmail,
      photoUrl: _currentUser!.photoUrl,
    );
    _currentUser = updatedUser;
    await LocalStorageService.saveCurrentUser(updatedUser);
    notifyListeners();
    return true;
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    await Future.delayed(const Duration(milliseconds: 300));
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _currentUser = null;
    await LocalStorageService.clearCurrentUser();
    notifyListeners();
  }
}
