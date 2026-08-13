import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:expense_tracker/providers/auth_provider.dart';
import 'package:expense_tracker/services/local_storage_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('./test_hive');
    await Hive.openBox(LocalStorageService.transactionsBoxName);
    await Hive.openBox(LocalStorageService.categoriesBoxName);
    await Hive.openBox(LocalStorageService.budgetsBoxName);
    await Hive.openBox(LocalStorageService.savingsBoxName);
    await Hive.openBox(LocalStorageService.settingsBoxName);
    await Hive.openBox(LocalStorageService.usersBoxName);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  group('Local AuthProvider Tests', () {
    test('Register new account successfully', () async {
      final auth = AuthProvider();
      final success = await auth.register('Test User', 'test@pocketify.app', 'password123');

      expect(success, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser, isNotNull);
      expect(auth.currentUser!.name, 'Test User');
      expect(auth.currentUser!.email, 'test@pocketify.app');
    });

    test('Register fails when account already exists', () async {
      final auth = AuthProvider();
      final success = await auth.register('Duplicate User', 'test@pocketify.app', 'password123');

      expect(success, isFalse);
      expect(auth.errorMessage, contains('already exists'));
    });

    test('Logout clears authenticated state and session', () async {
      final auth = AuthProvider();
      await auth.logout();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
      expect(LocalStorageService.getCurrentUser(), isNull);
    });

    test('Login fails with wrong password', () async {
      final auth = AuthProvider();
      await auth.logout();
      final success = await auth.login('test@pocketify.app', 'wrongpassword');

      expect(success, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, contains('Incorrect'));
    });

    test('Login succeeds with correct password', () async {
      final auth = AuthProvider();
      final success = await auth.login('test@pocketify.app', 'password123');

      expect(success, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser!.email, 'test@pocketify.app');
    });
  });
}
