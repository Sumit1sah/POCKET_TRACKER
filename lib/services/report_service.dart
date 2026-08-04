import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction_model.dart';
import '../utils/formatters.dart';

class ReportService {
  /// Generates a CSV data export and triggers local file sharing
  static Future<String> generateCSVReport(
    List<TransactionModel> transactions, {
    String? monthTitle,
  }) async {
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
    final prefix = monthTitle != null
        ? 'Pocketify_Report_${monthTitle.replaceAll(' ', '_')}'
        : 'Pocketify_Report';
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.csv';

    final bytes = Uint8List.fromList(utf8.encode(csvData));
    await Printing.sharePdf(bytes: bytes, filename: fileName);
    return fileName;
  }

  /// Generates an executive-ready, highly attractive PDF Financial Statement
  static Future<void> printPDFReport(
    List<TransactionModel> transactions,
    String currencySymbol, {
    String? monthTitle,
  }) async {
    final pdf = pw.Document();

    // Load Unicode TrueType font (Roboto) to support global currency symbols (₹, $, €, £, ¥)
    pw.Font? fontBase;
    pw.Font? fontBold;

    try {
      fontBase = await PdfGoogleFonts.robotoRegular();
      fontBold = await PdfGoogleFonts.robotoBold();
    } catch (_) {
      try {
        fontBase = await PdfGoogleFonts.interRegular();
        fontBold = await PdfGoogleFonts.interBold();
      } catch (_) {
        // Fallback to standard PDF font if offline
      }
    }

    final themeData = (fontBase != null && fontBold != null)
        ? pw.ThemeData.withFont(base: fontBase, bold: fontBold)
        : pw.ThemeData.base();

    // Safe symbol for PDF if offline standard font fallback is used
    final effectiveSymbol = (fontBase == null && currencySymbol == '₹')
        ? 'INR '
        : currencySymbol;

    final incomeTotal = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final expenseTotal = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final netSavings = incomeTotal - expenseTotal;
    final savingsRate = incomeTotal > 0
        ? (netSavings / incomeTotal * 100.0)
        : (netSavings > 0 ? 100.0 : 0.0);

    // Compute Category Breakdown for top spending summary
    final Map<String, double> catTotals = {};
    for (final t in transactions.where((t) => t.type == TransactionType.expense)) {
      catTotals[t.category] = (catTotals[t.category] ?? 0.0) + t.amount;
    }
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCats = sortedCats.take(5).toList();

    final primaryColor = PdfColor.fromHex('#6C5CE7');
    final darkBg = PdfColor.fromHex('#1E1C2E');
    final accentGreen = PdfColor.fromHex('#00B894');
    final accentRed = PdfColor.fromHex('#FF7675');
    final accentBlue = PdfColor.fromHex('#0984E3');
    final lightGrey = PdfColor.fromHex('#F8F9FE');
    final borderGrey = PdfColor.fromHex('#E0E0EC');

    final titleText = monthTitle != null
        ? 'Monthly Financial Statement - $monthTitle'
        : 'Pocketify Financial Statement';
    final issueDate = Formatters.formatDate(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        theme: themeData,
        pageFormat: PdfPageFormat.a4.copyWith(
          marginTop: 28,
          marginBottom: 28,
          marginLeft: 28,
          marginRight: 28,
        ),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: darkBg,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 32,
                          height: 32,
                          decoration: pw.BoxDecoration(
                            color: primaryColor,
                            shape: pw.BoxShape.circle,
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'P',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'POCKETIFY',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 15,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            pw.Text(
                              'Smart Expense Tracker & Financial Intelligence',
                              style: pw.TextStyle(
                                color: PdfColor.fromHex('#A0A0C0'),
                                fontSize: 8.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'OFFICIAL STATEMENT',
                          style: pw.TextStyle(
                            color: primaryColor,
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Issued: $issueDate',
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#D0D0E0'),
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: borderGrey, thickness: 1),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Confidential • Generated by Pocketify App',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) => [
          // Title Banner
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F0ECFF'),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: primaryColor.shade(0.3)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  titleText,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.Text(
                  '${transactions.length} Total Records',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Executive Summary 4-Card Grid
          pw.Row(
            children: [
              _buildSummaryCard(
                title: 'TOTAL INCOME',
                value: Formatters.formatCurrency(incomeTotal, symbol: effectiveSymbol),
                accentColor: accentGreen,
                bgColor: PdfColor.fromHex('#E6F9F0'),
              ),
              pw.SizedBox(width: 8),
              _buildSummaryCard(
                title: 'TOTAL EXPENSE',
                value: Formatters.formatCurrency(expenseTotal, symbol: effectiveSymbol),
                accentColor: accentRed,
                bgColor: PdfColor.fromHex('#FFEDED'),
              ),
              pw.SizedBox(width: 8),
              _buildSummaryCard(
                title: 'NET SAVINGS',
                value: Formatters.formatCurrency(netSavings, symbol: effectiveSymbol),
                accentColor: accentBlue,
                bgColor: PdfColor.fromHex('#EBF3FF'),
              ),
              pw.SizedBox(width: 8),
              _buildSummaryCard(
                title: 'SAVINGS RATE',
                value: '${savingsRate.toStringAsFixed(1)}%',
                accentColor: primaryColor,
                bgColor: PdfColor.fromHex('#F0EDFF'),
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          // Top Spending Categories Section
          if (topCats.isNotEmpty) ...[
            pw.Text(
              'TOP EXPENSE CATEGORIES',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: lightGrey,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderGrey),
              ),
              child: pw.Column(
                children: topCats.map((cat) {
                  final catPct = expenseTotal > 0 ? (cat.value / expenseTotal * 100.0) : 0.0;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 100,
                          child: pw.Text(
                            cat.key,
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Stack(
                            children: [
                              pw.Container(
                                height: 7,
                                decoration: pw.BoxDecoration(
                                  color: borderGrey,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                              ),
                              pw.Container(
                                height: 7,
                                width: (catPct / 100) * 200,
                                decoration: pw.BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          '${catPct.toStringAsFixed(1)}%',
                          style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                        ),
                        pw.SizedBox(width: 14),
                        pw.Text(
                          Formatters.formatCurrency(cat.value, symbol: effectiveSymbol),
                          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            pw.SizedBox(height: 14),
          ],

          // Transaction Ledger Title
          pw.Text(
            'TRANSACTION LEDGER DETAILS',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.5,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 6),

          // Styled Transaction Table
          if (transactions.isEmpty)
            pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(20),
                child: pw.Text('No transactions recorded for this period.'),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: borderGrey, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(55),  // Date
                1: pw.FlexColumnWidth(2.5),  // Title/Description
                2: pw.FlexColumnWidth(1.8),  // Category
                3: pw.FlexColumnWidth(1.5),  // Payment Method
                4: pw.FixedColumnWidth(50),  // Type
                5: pw.FlexColumnWidth(1.8),  // Amount
              },
              children: [
                // Table Header Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primaryColor),
                  children: [
                    _buildTableCell('DATE', isHeader: true),
                    _buildTableCell('DESCRIPTION', isHeader: true),
                    _buildTableCell('CATEGORY', isHeader: true),
                    _buildTableCell('PAYMENT', isHeader: true),
                    _buildTableCell('TYPE', isHeader: true, alignRight: true),
                    _buildTableCell('AMOUNT', isHeader: true, alignRight: true),
                  ],
                ),
                // Table Data Rows
                ...transactions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final t = entry.value;
                  final isEven = index % 2 == 0;
                  final isIncome = t.type == TransactionType.income;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.white : lightGrey,
                    ),
                    children: [
                      _buildTableCell(Formatters.formatShortDate(t.date)),
                      _buildTableCell(t.description.isNotEmpty ? t.description : 'Transaction'),
                      _buildTableCell(t.category),
                      _buildTableCell(t.paymentMethod),
                      _buildTableCell(
                        isIncome ? 'INCOME' : 'EXPENSE',
                        textColor: isIncome ? accentGreen : accentRed,
                        alignRight: true,
                        isBold: true,
                      ),
                      _buildTableCell(
                        '${isIncome ? '+' : '-'} ${Formatters.formatCurrency(t.amount, symbol: effectiveSymbol)}',
                        textColor: isIncome ? accentGreen : accentRed,
                        alignRight: true,
                        isBold: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );

    final prefix = monthTitle != null
        ? 'Pocketify_Statement_${monthTitle.replaceAll(' ', '_')}'
        : 'Pocketify_Statement';
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    await Printing.layoutPdf(
      name: fileName,
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static pw.Widget _buildSummaryCard({
    required String title,
    required String value,
    required PdfColor accentColor,
    required PdfColor bgColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: accentColor.shade(0.3), width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
                letterSpacing: 0.3,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool alignRight = false,
    bool isBold = false,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: isHeader ? 7.5 : 8,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader
              ? PdfColors.white
              : (textColor ?? PdfColors.black),
        ),
      ),
    );
  }
}
