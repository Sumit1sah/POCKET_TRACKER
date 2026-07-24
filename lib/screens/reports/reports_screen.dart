import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../services/report_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Reports'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate & Share Financial Reports',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Export your complete income and expense statements for budgeting or tax filing.',
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 24),

            // PDF Export Option
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.red),
                ),
                title: const Text('Generate PDF Statement', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Print or share formatted PDF statement'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await ReportService.printPDFReport(txProvider.transactions, currency);
                },
              ),
            ),
            const SizedBox(height: 16),

            // CSV Export Option
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.table_chart, color: Colors.green),
                ),
                title: const Text('Export CSV Data File', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Download raw spreadsheet data (.csv)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final csvFile = await ReportService.generateCSVReport(txProvider.transactions);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('CSV exported successfully: ${csvFile.path}')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
