import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../models/category_model.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catProvider = Provider.of<CategoryProvider>(context);
    final expenseCats = catProvider.expenseCategories;
    final incomeCats = catProvider.incomeCategories;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Categories'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.money_off_rounded), text: 'Expense Categories'),
              Tab(icon: Icon(Icons.attach_money_rounded), text: 'Income Categories'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add Custom Category',
              onPressed: () => _showAddCategoryDialog(context),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildCategoryList(context, expenseCats, catProvider, isExpenseTab: true),
            _buildCategoryList(context, incomeCats, catProvider, isExpenseTab: false),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    List<CategoryModel> categories,
    CategoryProvider catProvider, {
    required bool isExpenseTab,
  }) {
    if (categories.isEmpty) {
      return const Center(child: Text('No categories found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final bool isDeducting = cat.deductFromBudget;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 1.5,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(cat.iconData, color: cat.color),
            ),
            title: Text(
              cat.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: isExpenseTab
                  ? Row(
                      children: [
                        Icon(
                          isDeducting ? Icons.check_circle_outline : Icons.block_outlined,
                          size: 13,
                          color: isDeducting ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isDeducting ? 'Deducts from Monthly Budget' : 'Excluded from Monthly Budget',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDeducting ? Colors.green.shade700 : Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : const Text('Income Category', style: TextStyle(fontSize: 12)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isExpenseTab)
                  IconButton(
                    icon: Icon(
                      isDeducting ? Icons.account_balance_wallet_outlined : Icons.money_off_outlined,
                      color: isDeducting ? Colors.green : Colors.grey,
                    ),
                    tooltip: isDeducting ? 'Deducts from Budget' : 'Excluded from Budget',
                    onPressed: () => _toggleBudgetDeduction(context, catProvider, cat),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                  tooltip: 'Edit Category',
                  onPressed: () => _showEditCategoryDialog(context, catProvider, cat),
                ),
                if (!cat.isDefault)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Delete Category',
                    onPressed: () => catProvider.deleteCategory(cat.id),
                  ),
              ],
            ),
            onTap: () => _showEditCategoryDialog(context, catProvider, cat),
          ),
        );
      },
    );
  }

  void _toggleBudgetDeduction(
    BuildContext context,
    CategoryProvider catProvider,
    CategoryModel cat,
  ) {
    final updated = cat.copyWith(deductFromBudget: !cat.deductFromBudget);
    catProvider.updateCategory(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.deductFromBudget
              ? '"${cat.name}" will now deduct from monthly budget.'
              : '"${cat.name}" will be excluded from monthly budget.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    bool isIncome = false;
    bool deductFromBudget = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('Add Custom Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Is Income Category'),
                      subtitle: const Text('Income categories do not deduct from budget'),
                      value: isIncome,
                      onChanged: (val) => setState(() {
                        isIncome = val;
                        if (val) deductFromBudget = false;
                      }),
                    ),
                    if (!isIncome) ...[
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Deduct from Monthly Budget'),
                        subtitle: const Text(
                          'When enabled, expenses in this category count towards your monthly budget limit.',
                        ),
                        value: deductFromBudget,
                        onChanged: (val) => setState(() => deductFromBudget = val),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      final catProvider = Provider.of<CategoryProvider>(context, listen: false);
                      catProvider.addCategory(
                        CategoryModel(
                          id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                          uid: 'local_user',
                          name: nameController.text.trim(),
                          iconCodePoint: isIncome ? Icons.attach_money.codePoint : Icons.category.codePoint,
                          colorValue: isIncome ? Colors.green.toARGB32() : Colors.purple.toARGB32(),
                          isIncome: isIncome,
                          deductFromBudget: isIncome ? false : deductFromBudget,
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

  void _showEditCategoryDialog(
    BuildContext context,
    CategoryProvider catProvider,
    CategoryModel cat,
  ) {
    final nameController = TextEditingController(text: cat.name);
    bool deductFromBudget = cat.deductFromBudget;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text('Edit "${cat.name}"'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!cat.isDefault)
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Category Name',
                          border: OutlineInputBorder(),
                        ),
                      )
                    else
                      ListTile(
                        title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Default system category'),
                        leading: CircleAvatar(
                          backgroundColor: cat.color.withValues(alpha: 0.2),
                          child: Icon(cat.iconData, color: cat.color),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (!cat.isIncome) ...[
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Deduct from Monthly Budget'),
                        subtitle: const Text(
                          'When enabled, expenses in this category are deducted from your monthly budget limit.',
                        ),
                        value: deductFromBudget,
                        onChanged: (val) => setState(() => deductFromBudget = val),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newName = cat.isDefault ? cat.name : nameController.text.trim();
                    if (newName.isNotEmpty) {
                      catProvider.updateCategory(
                        cat.copyWith(
                          name: newName,
                          deductFromBudget: cat.isIncome ? false : deductFromBudget,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
