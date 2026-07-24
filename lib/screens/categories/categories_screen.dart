import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../models/category_model.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catProvider = Provider.of<CategoryProvider>(context);
    final categories = catProvider.categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddCategoryDialog(context),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(cat.iconData, color: cat.color),
              ),
              title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(cat.isIncome ? 'Income Category' : 'Expense Category'),
              trailing: cat.isDefault
                  ? const Chip(label: Text('Default', style: TextStyle(fontSize: 10)))
                  : IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => catProvider.deleteCategory(cat.id),
                    ),
            ),
          );
        },
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    bool isIncome = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Custom Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Category Name'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Is Income Category'),
                      value: isIncome,
                      onChanged: (val) => setState(() => isIncome = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      final catProvider = Provider.of<CategoryProvider>(context, listen: false);
                      catProvider.addCategory(
                        CategoryModel(
                          id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                          uid: 'local_user',
                          name: nameController.text.trim(),
                          iconCodePoint: Icons.category.codePoint,
                          colorValue: Colors.purple.toARGB32(),
                          isIncome: isIncome,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
