import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction_model.dart';
import '../utils/formatters.dart';

class ReportService {
  static Future<String> generateCSVReport(List<TransactionModel> transactions, {String? monthTitle}) async {
    final List<List<dynamic>> rows = [
      ['Transaction ID', 'Type', 'Amount', 'Category', 'Payment Method', 'Date', 'Description'],
    ];

    for (final t in transactions) {
      rows.add([
        t.id,
        t.type.name,
        t.amount,
        t.category,
        t.paymentMethod,
        Formatters.formatDate(t.date),
        t.description,
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final prefix = monthTitle != null ? 'Pocketify_Report_${monthTitle.replaceAll(' ', '_')}' : 'Pocketify_Report';
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.csv';

    final bytes = Uint8List.fromList(utf8.encode(csvData));
    await Printing.sharePdf(bytes: bytes, filename: fileName);
    return fileName;
  }

  static Future<void> printPDFReport(List<TransactionModel> transactions, String currencySymbol, {String? monthTitle}) async {
    final pdf = pw.Document();

    final incomeTotal = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final expenseTotal = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final titleText = monthTitle != null ? 'Pocketify Monthly Financial Statement - $monthTitle' : 'Pocketify Financial Report';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(titleText, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Text(Formatters.formatDate(DateTime.now()), style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(children: [
                pw.Text('Total Income', style: const pw.TextStyle(fontSize: 12)),
                pw.Text(Formatters.formatCurrency(incomeTotal, symbol: currencySymbol),
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
              ]),
              pw.Column(children: [
                pw.Text('Total Expense', style: const pw.TextStyle(fontSize: 12)),
                pw.Text(Formatters.formatCurrency(expenseTotal, symbol: currencySymbol),
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
              ]),
              pw.Column(children: [
                pw.Text('Net Savings', style: const pw.TextStyle(fontSize: 12)),
                pw.Text(Formatters.formatCurrency(incomeTotal - expenseTotal, symbol: currencySymbol),
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
              ]),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Type', 'Category', 'Payment', 'Amount', 'Notes'],
            data: transactions.map((t) => [
              Formatters.formatShortDate(t.date),
              t.type.name.toUpperCase(),
              t.category,
              t.paymentMethod,
              Formatters.formatCurrency(t.amount, symbol: currencySymbol),
              t.description,
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
