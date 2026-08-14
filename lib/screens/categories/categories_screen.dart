import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../models/category_model.dart';
import '../../widgets/category_icon_widget.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static final List<IconData> _expenseIcons = [
    Icons.fastfood_rounded,
    Icons.restaurant_rounded,
    Icons.local_cafe_rounded,
    Icons.local_pizza_rounded,
    Icons.shopping_bag_rounded,
    Icons.shopping_cart_rounded,
    Icons.shopping_basket_rounded,
    Icons.local_grocery_store_rounded,
    Icons.directions_car_rounded,
    Icons.local_gas_station_rounded,
    Icons.flight_takeoff_rounded,
    Icons.directions_bus_rounded,
    Icons.train_rounded,
    Icons.home_rounded,
    Icons.house_rounded,
    Icons.flash_on_rounded,
    Icons.water_drop_rounded,
    Icons.school_rounded,
    Icons.laptop_mac_rounded,
    Icons.phone_android_rounded,
    Icons.medical_services_rounded,
    Icons.local_hospital_rounded,
    Icons.health_and_safety_rounded,
    Icons.movie_rounded,
    Icons.sports_esports_rounded,
    Icons.music_note_rounded,
    Icons.fitness_center_rounded,
    Icons.pets_rounded,
    Icons.subscriptions_rounded,
    Icons.receipt_long_rounded,
    Icons.build_rounded,
    Icons.credit_card_rounded,
    Icons.payments_rounded,
    Icons.spa_rounded,
    Icons.child_care_rounded,
    Icons.family_restroom_rounded,
    Icons.category_rounded,
  ];

  static final List<IconData> _incomeIcons = [
    Icons.account_balance_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.payments_rounded,
    Icons.attach_money_rounded,
    Icons.currency_exchange_rounded,
    Icons.savings_rounded,
    Icons.trending_up_rounded,
    Icons.show_chart_rounded,
    Icons.insights_rounded,
    Icons.work_rounded,
    Icons.card_giftcard_rounded,
    Icons.redeem_rounded,
    Icons.price_check_rounded,
    Icons.price_change_rounded,
    Icons.replay_rounded,
    Icons.wallet_rounded,
    Icons.credit_score_rounded,
    Icons.credit_card_rounded,
    Icons.star_rounded,
    Icons.analytics_rounded,
    Icons.assessment_rounded,
  ];

  static final List<Color> _availableColors = [
    const Color(0xFF6C5CE7), // Purple / Indigo
    const Color(0xFFFF7675), // Coral
    const Color(0xFF00B894), // Emerald Green
    const Color(0xFF0984E3), // Ocean Blue
    const Color(0xFFFDCB6E), // Gold
    const Color(0xFFE84393), // Pink
    const Color(0xFF00CEC9), // Cyan
    const Color(0xFF636E72), // Slate
    const Color(0xFFD63031), // Deep Red
    const Color(0xFFE17055), // Burnt Orange
    const Color(0xFFA29BFE), // Lavender
    const Color(0xFF55EFC4), // Mint
  ];

  @override
  Widget build(BuildContext context) {
    final catProvider = Provider.of<CategoryProvider>(context);
    final expenseCats = catProvider.expenseCategories;
    final incomeCats = catProvider.incomeCategories;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Manage Categories',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            isScrollable: false,
            labelPadding: EdgeInsets.symmetric(horizontal: 8),
            tabs: [
              Tab(icon: Icon(Icons.money_off_rounded, size: 20), text: 'Expense Categories'),
              Tab(icon: Icon(Icons.attach_money_rounded, size: 20), text: 'Income Categories'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Add Custom Category',
              onPressed: () => _showAddCategoryModal(context),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildCategoryList(context, expenseCats, catProvider, isExpenseTab: true, isDark: isDark),
            _buildCategoryList(context, incomeCats, catProvider, isExpenseTab: false, isDark: isDark),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddCategoryModal(context),
          backgroundColor: const Color(0xFF6C5CE7),
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    List<CategoryModel> categories,
    CategoryProvider catProvider, {
    required bool isExpenseTab,
    required bool isDark,
  }) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No categories found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddCategoryModal(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add New Category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final bool isDeducting = cat.deductFromBudget;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 1.5,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CategoryIconWidget(
              category: cat,
              size: 44,
              iconSize: 20,
              showTypeBadge: true,
            ),
            title: Text(
              cat.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: isExpenseTab
                  ? Row(
                      children: [
                        Icon(
                          isDeducting ? Icons.check_circle_outline : Icons.block_outlined,
                          size: 13,
                          color: isDeducting ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isDeducting ? 'Deducts from Budget' : 'Excluded from Budget',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDeducting ? Colors.green.shade700 : Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Income Category',
                      style: TextStyle(fontSize: 11.5),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isExpenseTab)
                  IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      isDeducting ? Icons.account_balance_wallet_outlined : Icons.money_off_outlined,
                      color: isDeducting ? Colors.green : Colors.grey,
                    ),
                    tooltip: isDeducting ? 'Deducts from Budget' : 'Excluded from Budget',
                    onPressed: () => _toggleBudgetDeduction(context, catProvider, cat),
                  ),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                  tooltip: 'Edit Category',
                  onPressed: () => _showEditCategoryModal(context, catProvider, cat),
                ),
                if (!cat.isDefault)
                  IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Delete Category',
                    onPressed: () => _confirmDeleteCategory(context, catProvider, cat),
                  ),
              ],
            ),
            onTap: () => _showEditCategoryModal(context, catProvider, cat),
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

  void _confirmDeleteCategory(
    BuildContext context,
    CategoryProvider catProvider,
    CategoryModel cat,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete "${cat.name}"?'),
        content: const Text('Are you sure you want to delete this custom category? Existing transactions will retain their historical logs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              catProvider.deleteCategory(cat.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Category "${cat.name}" deleted.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryModal(BuildContext context) {
    final nameController = TextEditingController();
    bool isIncome = false;
    bool deductFromBudget = true;
    IconData selectedIcon = _expenseIcons.first;
    Color selectedColor = _availableColors.first;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Header Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Create Custom Category',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Live Preview Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selectedColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selectedColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            CategoryIconWidget(
                              iconData: selectedIcon,
                              color: selectedColor,
                              isIncome: isIncome,
                              size: 48,
                              iconSize: 24,
                              showTypeBadge: true,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nameController.text.trim().isEmpty
                                        ? 'Category Name'
                                        : nameController.text.trim(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isIncome
                                        ? 'Income Category'
                                        : (deductFromBudget
                                            ? 'Expense • Deducts from Budget'
                                            : 'Expense • Excluded from Budget'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isIncome
                                          ? Colors.green
                                          : (deductFromBudget ? selectedColor : Colors.orange.shade800),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Category Type Segmented Switch
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() {
                                isIncome = false;
                                deductFromBudget = true;
                                selectedColor = const Color(0xFF6C5CE7);
                                selectedIcon = _expenseIcons.first;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !isIncome
                                      ? const Color(0xFF6C5CE7)
                                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Expense',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: !isIncome ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() {
                                isIncome = true;
                                deductFromBudget = false;
                                selectedColor = const Color(0xFF00B894);
                                selectedIcon = _incomeIcons.first;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isIncome
                                      ? const Color(0xFF00B894)
                                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Income',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isIncome ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Name Text Field
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        maxLength: 24,
                        onChanged: (_) => setModalState(() => errorMessage = null),
                        decoration: InputDecoration(
                          labelText: 'Category Name',
                          hintText: 'e.g., Coffee, Gaming, Salary',
                          errorText: errorMessage,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          prefixIcon: const Icon(Icons.edit_note_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Color Selector
                      const Text(
                        'Select Color Accent',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _availableColors.length,
                          itemBuilder: (ctx, i) {
                            final c = _availableColors[i];
                            final isSelected = c.toARGB32() == selectedColor.toARGB32();

                            return GestureDetector(
                              onTap: () => setModalState(() => selectedColor = c),
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(color: Colors.white, width: 3)
                                      : null,
                                  boxShadow: isSelected
                                      ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8, offset: const Offset(0, 2))]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Icon Selector
                      Text(
                        isIncome ? 'Select Income Category Icon' : 'Select Expense Category Icon',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final currentIcons = isIncome ? _incomeIcons : _expenseIcons;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: currentIcons.length,
                            itemBuilder: (ctx, i) {
                              final icon = currentIcons[i];
                              final isSelected = icon.codePoint == selectedIcon.codePoint;

                              return GestureDetector(
                                onTap: () => setModalState(() => selectedIcon = icon),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? selectedColor
                                        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? selectedColor
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black54),
                                    size: 22,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      if (!isIncome) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Deduct from Monthly Budget', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text('Expenses in this category count towards your spending limit.', style: TextStyle(fontSize: 12)),
                          value: deductFromBudget,
                          onChanged: (val) => setModalState(() => deductFromBudget = val),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Create Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 3,
                          ),
                          onPressed: () {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              setModalState(() => errorMessage = 'Please enter a category name');
                              return;
                            }

                            final catProvider = Provider.of<CategoryProvider>(context, listen: false);
                            final exists = catProvider.categories.any(
                                (c) => c.name.toLowerCase() == name.toLowerCase() && c.isIncome == isIncome);
                            if (exists) {
                              setModalState(() => errorMessage = 'Category "$name" already exists');
                              return;
                            }

                            catProvider.addCategory(
                              CategoryModel(
                                id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                                uid: 'local_user',
                                name: name,
                                iconCodePoint: selectedIcon.codePoint,
                                colorValue: selectedColor.toARGB32(),
                                isIncome: isIncome,
                                deductFromBudget: isIncome ? false : deductFromBudget,
                              ),
                            );

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Category "$name" created successfully!'),
                                backgroundColor: selectedColor,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text('Save Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditCategoryModal(
    BuildContext context,
    CategoryProvider catProvider,
    CategoryModel cat,
  ) {
    final nameController = TextEditingController(text: cat.name);
    bool deductFromBudget = cat.deductFromBudget;
    IconData selectedIcon = cat.iconData;
    Color selectedColor = cat.color;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Edit "${cat.name}"',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Live Preview Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selectedColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selectedColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            CategoryIconWidget(
                              iconData: selectedIcon,
                              color: selectedColor,
                              isIncome: cat.isIncome,
                              size: 48,
                              iconSize: 24,
                              showTypeBadge: true,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.isDefault ? cat.name : (nameController.text.trim().isEmpty ? cat.name : nameController.text.trim()),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cat.isIncome
                                        ? 'Income Category'
                                        : (deductFromBudget
                                            ? 'Expense • Deducts from Budget'
                                            : 'Expense • Excluded from Budget'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cat.isIncome
                                          ? Colors.green
                                          : (deductFromBudget ? selectedColor : Colors.orange.shade800),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (!cat.isDefault) ...[
                        TextField(
                          controller: nameController,
                          maxLength: 24,
                          onChanged: (_) => setModalState(() => errorMessage = null),
                          decoration: InputDecoration(
                            labelText: 'Category Name',
                            errorText: errorMessage,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            prefixIcon: const Icon(Icons.edit_note_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Color Selector
                      const Text(
                        'Select Color Accent',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _availableColors.length,
                          itemBuilder: (ctx, i) {
                            final c = _availableColors[i];
                            final isSelected = c.toARGB32() == selectedColor.toARGB32();

                            return GestureDetector(
                              onTap: () => setModalState(() => selectedColor = c),
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(color: Colors.white, width: 3)
                                      : null,
                                  boxShadow: isSelected
                                      ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8, offset: const Offset(0, 2))]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Icon Selector
                      Text(
                        cat.isIncome ? 'Select Income Category Icon' : 'Select Expense Category Icon',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final currentIcons = List<IconData>.from(cat.isIncome ? _incomeIcons : _expenseIcons);
                          if (!currentIcons.any((ic) => ic.codePoint == selectedIcon.codePoint)) {
                            currentIcons.insert(0, selectedIcon);
                          }

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: currentIcons.length,
                            itemBuilder: (ctx, i) {
                              final icon = currentIcons[i];
                              final isSelected = icon.codePoint == selectedIcon.codePoint;

                              return GestureDetector(
                                onTap: () => setModalState(() => selectedIcon = icon),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? selectedColor
                                        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? selectedColor
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black54),
                                    size: 22,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      if (!cat.isIncome) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Deduct from Monthly Budget', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text('Expenses in this category count towards your spending limit.', style: TextStyle(fontSize: 12)),
                          value: deductFromBudget,
                          onChanged: (val) => setModalState(() => deductFromBudget = val),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 3,
                          ),
                          onPressed: () {
                            final newName = cat.isDefault ? cat.name : nameController.text.trim();
                            if (newName.isEmpty) {
                              setModalState(() => errorMessage = 'Please enter a category name');
                              return;
                            }

                            catProvider.updateCategory(
                              cat.copyWith(
                                name: newName,
                                iconCodePoint: selectedIcon.codePoint,
                                colorValue: selectedColor.toARGB32(),
                                deductFromBudget: cat.isIncome ? false : deductFromBudget,
                              ),
                            );

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Category "$newName" updated!'),
                                backgroundColor: selectedColor,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
