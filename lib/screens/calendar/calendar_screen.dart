import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/transaction_tile.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);

    final dayTransactions = txProvider.transactions.where((t) =>
        t.date.year == _selectedDate.year &&
        t.date.month == _selectedDate.month &&
        t.date.day == _selectedDate.day).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar View'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            CalendarDatePicker(
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              onDateChanged: (newDate) {
                setState(() => _selectedDate = newDate);
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transactions on ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${dayTransactions.length} entries', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            if (dayTransactions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No transactions recorded on this day.')),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: dayTransactions.length,
                itemBuilder: (context, index) {
                  return TransactionTile(
                    transaction: dayTransactions[index],
                    onDelete: () => txProvider.deleteTransaction(dayTransactions[index].id),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
