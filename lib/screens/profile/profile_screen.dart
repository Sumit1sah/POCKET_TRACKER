import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../services/local_storage_service.dart';
import '../../utils/constants.dart';
import '../reports/reports_screen.dart';
import '../categories/categories_screen.dart';
import '../calendar/calendar_screen.dart';
import '../authentication/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: Color(0xFF6C5CE7)),
              SizedBox(width: 8),
              Text('Change Password'),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Enter current password' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.key_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.length < 6 ? 'Password must be 6+ characters' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.check_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val != newPasswordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  await authProvider.changePassword(
                    currentPasswordController.text,
                    newPasswordController.text,
                  );
                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password changed successfully!')),
                    );
                  }
                }
              },
              child: const Text('Update Password'),
            ),
          ],
        );
      },
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final nameController = TextEditingController(text: authProvider.currentUser?.name ?? '');
    final emailController = TextEditingController(text: authProvider.currentUser?.email ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit, color: Color(0xFF6C5CE7)),
              SizedBox(width: 8),
              Text('Edit Profile'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty && emailController.text.trim().isNotEmpty) {
                  await authProvider.updateProfileDetails(
                    nameController.text.trim(),
                    emailController.text.trim(),
                  );
                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Login details updated successfully!')),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF6C5CE7)),
              SizedBox(width: 8),
              Text('About Pocketify'),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pocketify – Smart Expense Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Version 1.0.0+1 (Production Release)'),
                SizedBox(height: 12),
                Text('Pocketify is a smart personal finance management app featuring offline-first storage, real-time analytics, AI spending insights, budget allocation, PDF/CSV report generation, and OCR receipt scanning.'),
              ],
            ),
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Logout Account'),
            ],
          ),
          content: const Text('Are you sure you want to log out of Pocketify?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeCurrencyProvider = Provider.of<ThemeCurrencyProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Logout Account',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // User Avatar & Profile Summary
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  child: Text(
                    authProvider.currentUser?.name.characters.first.toUpperCase() ?? 'P',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                ),
                InkWell(
                  onTap: () => _showEditProfileDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              authProvider.currentUser?.name ?? 'Alex Johnson',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              authProvider.currentUser?.email ?? 'alex@pocketify.app',
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 24),

            // Card 1: Account & Security Options
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: Color(0xFF6C5CE7)),
                    title: const Text('Edit Profile Details'),
                    subtitle: const Text('Update your name & email'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showEditProfileDialog(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_reset, color: Color(0xFF6C5CE7)),
                    title: const Text('Change Password'),
                    subtitle: const Text('Update account security password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint, color: Color(0xFF6C5CE7)),
                    title: const Text('Biometric / PIN Lock'),
                    subtitle: const Text('Require authentication to open app'),
                    value: _biometricEnabled,
                    onChanged: (val) {
                      setState(() => _biometricEnabled = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(val ? 'Biometric security enabled!' : 'Biometric security disabled.')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: App Preferences
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.currency_exchange, color: Color(0xFF00CEC9)),
                    title: const Text('Primary Currency'),
                    trailing: DropdownButton<String>(
                      value: themeCurrencyProvider.currency,
                      underline: const SizedBox.shrink(),
                      items: AppConstants.defaultCurrencies.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) themeCurrencyProvider.setCurrency(val);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined, color: Color(0xFF00CEC9)),
                    title: const Text('Dark Mode Theme'),
                    value: themeCurrencyProvider.isDarkMode,
                    onChanged: (val) => themeCurrencyProvider.toggleDarkMode(val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined, color: Color(0xFF00CEC9)),
                    title: const Text('Push Notifications'),
                    subtitle: const Text('Budget alerts & daily reminders'),
                    value: _notificationsEnabled,
                    onChanged: (val) {
                      setState(() => _notificationsEnabled = val);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.credit_card_outlined, color: Color(0xFF6C5CE7)),
                    title: const Text('Credit Card Tracking'),
                    subtitle: const Text('Show credit card limits & balance on dashboard'),
                    value: LocalStorageService.getCCPreference() ?? false,
                    onChanged: (val) async {
                      await LocalStorageService.setCCPreference(val);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: Features & Export Tools
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined, color: Color(0xFFFD79A8)),
                    title: const Text('Calendar View'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarScreen()));
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.category_outlined, color: Color(0xFFFD79A8)),
                    title: const Text('Category Management'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CategoriesScreen()));
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFFD79A8)),
                    title: const Text('Reports & Exports (PDF/CSV)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsScreen()));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 4: Support & About
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.blue),
                    title: const Text('About Pocketify'),
                    subtitle: const Text('App version 1.0.0'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showAboutDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Logout Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
