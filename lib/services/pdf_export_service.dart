import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/itr_models/itr_models.dart';

class PDFExportService {
  Future<void> exportProfitLossStatement(
    BuildContext context,
    ProfitLossStatement data,
  ) async {
    const companyName = 'FlashBill Business';
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Profit & Loss Statement',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Company: $companyName'),
              pw.Text(
                'Period: ${DateFormat('dd/MM/yyyy').format(data.periodStart)} - ${DateFormat('dd/MM/yyyy').format(data.periodEnd)}',
              ),
              pw.Text(
                'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              ),
              pw.SizedBox(height: 20),

              // Revenue Section
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Revenue',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildPDFRow('Total Revenue', data.totalRevenue),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // Expenses Section
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Expenses',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildPDFRow('Total Expenses', -data.totalExpenses),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // Profit Section
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                  color: PdfColors.grey100,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Profit Summary',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildPDFRow(
                      'Gross Profit',
                      data.grossProfit,
                      isBold: true,
                    ),
                    pw.SizedBox(height: 5),
                    _buildPDFRow(
                      'Net Profit',
                      data.netProfit,
                      isBold: true,
                      isLarge: true,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'profit_loss_statement.pdf',
    );
  }

  Future<void> exportBalanceSheet(
    BuildContext context,
    BalanceSheet data,
  ) async {
    const companyName = 'FlashBill Business';
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Balance Sheet',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Company: $companyName'),
              pw.Text(
                'As of: ${DateFormat('dd/MM/yyyy').format(data.asOfDate)}',
              ),
              pw.Text(
                'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              ),
              pw.SizedBox(height: 20),

              // Assets Section
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Assets',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildPDFRow('Total Assets', data.totalAssets),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // Liabilities Section
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Liabilities',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildPDFRow('Total Liabilities', -data.totalLiabilities),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // Equity Section
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                  color: PdfColors.grey100,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Equity',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildPDFRow('Net Worth', data.netWorth, isBold: true),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'balance_sheet.pdf',
    );
  }

  Future<void> exportGSTReport(BuildContext context, GSTReport data) async {
    const companyName = 'FlashBill Business';
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Text(
                  'GST Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Company: $companyName'),
              pw.Text(
                'Period: ${DateFormat('dd/MM/yyyy').format(data.periodStart)} - ${DateFormat('dd/MM/yyyy').format(data.periodEnd)}',
              ),
              pw.Text(
                'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              ),
              pw.SizedBox(height: 20),

              // GST Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'GST Summary',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildPDFRow('GST Collected', data.totalGSTCollected),
                    _buildPDFRow('GST Paid', -data.totalGSTPaid),
                    pw.Divider(),
                    _buildPDFRow(
                      'Net GST Liability',
                      data.netGSTLiability,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // Compliance Status
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                  color: data.netGSTLiability >= 0
                      ? PdfColors.red100
                      : PdfColors.green100,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Compliance Status',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      data.netGSTLiability > 0
                          ? 'GST Payable: ₹${data.netGSTLiability.abs().toStringAsFixed(2)}'
                          : data.netGSTLiability < 0
                          ? 'GST Refund Due: ₹${data.netGSTLiability.abs().toStringAsFixed(2)}'
                          : 'GST Compliant',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: data.netGSTLiability >= 0
                            ? PdfColors.red
                            : PdfColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'gst_report.pdf',
    );
  }

  Future<void> exportTaxSummary(BuildContext context, TaxSummary data) async {
    const companyName = 'FlashBill Business';
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Tax Summary',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Company: $companyName'),
              pw.Text(
                'Assessment Year: ${DateFormat('yyyy').format(DateTime(DateTime.now().year, 4, 1))}-${DateFormat('yy').format(DateTime(DateTime.now().year + 1, 3, 31))}',
              ),
              pw.Text(
                'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              ),
              pw.SizedBox(height: 20),

              // Income Details
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Income Details',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildPDFRow('Total Income', data.totalIncome),
                    _buildPDFRow('Total Deductions', -data.totalDeductions),
                    pw.Divider(),
                    _buildPDFRow(
                      'Taxable Income',
                      data.taxableIncome,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // Tax Calculation
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Tax Calculation',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildPDFRow('Tax Liability', data.taxLiability),
                    _buildPDFRow('Tax Paid', -data.taxPaid),
                    pw.Divider(),
                    _buildPDFRow(
                      'Tax Refund/Due',
                      data.taxRefund,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'tax_summary.pdf',
    );
  }

  static pw.Widget _buildPDFRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isLarge = false,
  }) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: isLarge ? 16 : 12,
          ),
        ),
        pw.Text(
          currencyFormat.format(amount.abs()),
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: isLarge ? 16 : 12,
            color: amount < 0 ? PdfColors.red : PdfColors.black,
          ),
        ),
      ],
    );
  }

  Future<void> exportSalesReport(
    BuildContext context,
    List<Map<String, dynamic>> salesData,
    DateTime startDate,
    DateTime endDate,
  ) async {
    const companyName = 'FlashBill Business';
    final totalSales = salesData.fold(
      0.0,
      (sum, item) => sum + (item['totalAmount'] as double),
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Sales Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Company: $companyName'),
              pw.Text(
                'Period: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
              ),
              pw.Text(
                'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              ),
              pw.SizedBox(height: 20),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Text(
                  'Total Sales: ${NumberFormat.currency(symbol: '₹').format(totalSales)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Sales Data Table
              pw.Text(
                'Sales Details:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Date', 'Bill ID', 'Customer', 'Amount (₹)'],
                data: salesData
                    .map(
                      (sale) => [
                        DateFormat('dd/MM/yyyy').format(sale['date']),
                        sale['id'].toString().substring(0, 8),
                        sale['customerName'],
                        NumberFormat.currency(
                          symbol: '₹',
                        ).format(sale['totalAmount']),
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> exportPurchaseReport(
    BuildContext context,
    List<Map<String, dynamic>> purchaseData,
    DateTime startDate,
    DateTime endDate,
  ) async {
    const companyName = 'FlashBill Business';
    final totalPurchases = purchaseData.fold(
      0.0,
      (sum, item) => sum + (item['totalAmount'] as double),
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Purchase Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Company: $companyName'),
              pw.Text(
                'Period: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
              ),
              pw.Text(
                'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              ),
              pw.SizedBox(height: 20),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Text(
                  'Total Purchases: ${NumberFormat.currency(symbol: '₹').format(totalPurchases)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Purchase Data Table
              pw.Text(
                'Purchase Details:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Date', 'Purchase ID', 'Supplier', 'Amount (₹)'],
                data: purchaseData
                    .map(
                      (purchase) => [
                        DateFormat('dd/MM/yyyy').format(purchase['date']),
                        purchase['id'].toString().substring(0, 8),
                        purchase['supplierName'],
                        NumberFormat.currency(
                          symbol: '₹',
                        ).format(purchase['totalAmount']),
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> exportExpenseReport(
    BuildContext context,
    List<Map<String, dynamic>> expenseData,
    DateTime startDate,
    DateTime endDate,
  ) async {
    const companyName = 'FlashBill Business';
    final totalExpenses = expenseData.fold(
      0.0,
      (sum, item) => sum + (item['amount'] as double),
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Expense Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Company: $companyName'),
              pw.Text(
                'Period: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
              ),
              pw.Text(
                'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              ),
              pw.SizedBox(height: 20),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Text(
                  'Total Expenses: ${NumberFormat.currency(symbol: '₹').format(totalExpenses)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Expense Data Table
              pw.Text(
                'Expense Details:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Date', 'Description', 'Category', 'Amount (₹)'],
                data: expenseData
                    .map(
                      (expense) => [
                        DateFormat('dd/MM/yyyy').format(expense['date']),
                        expense['description'],
                        expense['category'],
                        NumberFormat.currency(
                          symbol: '₹',
                        ).format(expense['amount']),
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
