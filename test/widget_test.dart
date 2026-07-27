import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/services/local_storage_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('.');
    await Hive.openBox(LocalStorageService.transactionsBoxName);
    await Hive.openBox(LocalStorageService.categoriesBoxName);
    await Hive.openBox(LocalStorageService.budgetsBoxName);
    await Hive.openBox(LocalStorageService.savingsBoxName);
    await Hive.openBox(LocalStorageService.settingsBoxName);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  testWidgets('PocketifyApp builds successfully smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PocketifyApp());
    expect(find.byType(PocketifyApp), findsOneWidget);
  });
}
