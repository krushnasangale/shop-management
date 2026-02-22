import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/itr_models/itr_models.dart';

class ExcelExportService {
  Future<void> exportProfitLossStatement(
    BuildContext context,
    ProfitLossStatement data,
  ) async {
    const companyName = 'FlashBill Business';
    final excel = Excel.createExcel();
    final sheet = excel['Profit & Loss Statement'];

    // Add header information
    sheet.appendRow([TextCellValue('Company:'), TextCellValue(companyName)]);
    sheet.appendRow([
      TextCellValue('Period:'),
      TextCellValue(
        '${DateFormat('dd/MM/yyyy').format(data.periodStart)} - ${DateFormat('dd/MM/yyyy').format(data.periodEnd)}',
      ),
    ]);
    sheet.appendRow([
      TextCellValue('Generated on:'),
      TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
    ]);
    sheet.appendRow([TextCellValue('')]); // Empty row

    // Add data headers
    sheet.appendRow([
      TextCellValue('Description'),
      TextCellValue('Amount (₹)'),
    ]);
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
    ]); // Empty row for spacing

    // Revenue section
    sheet.appendRow([TextCellValue('REVENUE'), TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('Total Revenue'),
      DoubleCellValue(data.totalRevenue),
    ]);
    sheet.appendRow([TextCellValue(''), TextCellValue('')]); // Empty row

    // Expenses section
    sheet.appendRow([TextCellValue('EXPENSES'), TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('Total Expenses'),
      DoubleCellValue(-data.totalExpenses),
    ]);
    sheet.appendRow([TextCellValue(''), TextCellValue('')]); // Empty row

    // Profit section
    sheet.appendRow([TextCellValue('PROFIT SUMMARY'), TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('Gross Profit'),
      DoubleCellValue(data.grossProfit),
    ]);
    sheet.appendRow([
      TextCellValue('Net Profit'),
      DoubleCellValue(data.netProfit),
    ]);

    await _saveAndShareExcel(excel, 'profit_loss_statement.xlsx');
  }

  Future<void> exportBalanceSheet(
    BuildContext context,
    BalanceSheet data,
  ) async {
    const companyName = 'FlashBill Business';
    final excel = Excel.createExcel();
    final sheet = excel['Balance Sheet'];

    // Add header information
    sheet.appendRow([TextCellValue('Company:'), TextCellValue(companyName)]);
    sheet.appendRow([
      TextCellValue('As of:'),
      TextCellValue(DateFormat('dd/MM/yyyy').format(data.asOfDate)),
    ]);
    sheet.appendRow([
      TextCellValue('Generated on:'),
      TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
    ]);
    sheet.appendRow([TextCellValue('')]); // Empty row

    // Add data headers
    sheet.appendRow([
      TextCellValue('Description'),
      TextCellValue('Amount (₹)'),
    ]);
    sheet.appendRow([TextCellValue(''), TextCellValue('')]); // Empty row

    // Assets section
    sheet.appendRow([TextCellValue('ASSETS'), TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('Total Assets'),
      DoubleCellValue(data.totalAssets),
    ]);
    sheet.appendRow([TextCellValue(''), TextCellValue('')]); // Empty row

    // Liabilities section
    sheet.appendRow([TextCellValue('LIABILITIES'), TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('Total Liabilities'),
      DoubleCellValue(-data.totalLiabilities),
    ]);
    sheet.appendRow([TextCellValue(''), TextCellValue('')]); // Empty row

    // Equity section
    sheet.appendRow([TextCellValue('EQUITY'), TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('Net Worth'),
      DoubleCellValue(data.netWorth),
    ]);

    await _saveAndShareExcel(excel, 'balance_sheet.xlsx');
  }

  Future<void> exportGSTReport(BuildContext context, GSTReport data) async {
    const companyName = 'FlashBill Business';
    final excel = Excel.createExcel();
    final sheet = excel['GST Report'];

    // Add header information
    sheet.appendRow([TextCellValue('Company:'), TextCellValue(companyName)]);
    sheet.appendRow([
      TextCellValue('Period:'),
      TextCellValue(
        '${DateFormat('dd/MM/yyyy').format(data.periodStart)} - ${DateFormat('dd/MM/yyyy').format(data.periodEnd)}',
      ),
    ]);
    sheet.appendRow([
      TextCellValue('Generated on:'),
      TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
    ]);
    sheet.appendRow([TextCellValue('')]); // Empty row

    // Add data headers
    sheet.appendRow([
      TextCellValue('Description'),
      TextCellValue('Amount (₹)'),
    ]);
    sheet.appendRow([TextCellValue(''), TextCellValue('')]); // Empty row

    // GST Summary
    sheet.appendRow([TextCellValue('GST SUMMARY'), TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('GST Collected'),
      DoubleCellValue(data.totalGSTCollected),
    ]);
    sheet.appendRow([
      TextCellValue('GST Paid'),
      DoubleCellValue(-data.totalGSTPaid),
    ]);
    sheet.appendRow([
      TextCellValue('Net GST Liability'),
      DoubleCellValue(data.netGSTLiability),
    ]);
    sheet.appendRow([TextCellValue(''), TextCellValue('')]); // Empty row

    // Compliance Status
    sheet.appendRow([TextCellValue('COMPLIANCE STATUS'), TextCellValue('')]);
    final status = data.netGSTLiability > 0
        ? 'GST Payable'
        : data.netGSTLiability < 0
        ? 'GST Refund Due'
        : 'GST Compliant';
    sheet.appendRow([TextCellValue('Status'), TextCellValue(status)]);

    await _saveAndShareExcel(excel, 'gst_report.xlsx');
  }

  Future<void> exportTaxSummary(BuildContext context, TaxSummary data) async {
    const companyName = 'FlashBill Business';
    final excel = Excel.createExcel();
    final sheet = excel['Tax Summary'];

    // Add header information
    sheet.appendRow([TextCellValue('Company:'), TextCellValue(companyName)]);
    sheet.appendRow([
      TextCellValue('Assessment Year:'),
      TextCellValue(
        '${DateFormat('yyyy').format(DateTime(DateTime.now().year, 4, 1))}-${DateFormat('yy').format(DateTime(DateTime.now().year + 1, 3, 31))}',
      ),
    ]);
    sheet.appendRow([
      TextCellValue('Generated on:'),
      TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
    ]);
    sheet.appendRow([TextCellValue('')]); // Empty row

    // Add data headers
    sheet.appendRow([
      TextCellValue('Description'),
      TextCellValue('Amount (₹)'),
    ]);
    sheet.appendRow([TextCellValue(''), TextCellValue('')]); // Empty row

    // Income Details
    sheet.appendRow([TextCellValue('INCOME DETAILS'), TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('Total Income'),
      DoubleCellValue(data.totalIncome),
    ]);
    sheet.appendRow([
      TextCellValue('Total Deductions'),
      DoubleCellValue(-data.totalDeductions),
    ]);
    sheet.appendRow([
      TextCellValue('Taxable Income'),
      DoubleCellValue(data.taxableIncome),
    ]);
    sheet.appendRow([TextCellValue(''), TextCellValue('')]); // Empty row

    // Tax Calculation
    sheet.appendRow([TextCellValue('TAX CALCULATION'), TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('Tax Liability'),
      DoubleCellValue(data.taxLiability),
    ]);
    sheet.appendRow([
      TextCellValue('Tax Paid'),
      DoubleCellValue(-data.taxPaid),
    ]);
    sheet.appendRow([
      TextCellValue('Tax Refund/Due'),
      DoubleCellValue(data.taxRefund),
    ]);

    await _saveAndShareExcel(excel, 'tax_summary.xlsx');
  }

  static Future<void> _saveAndShareExcel(Excel excel, String fileName) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // Save the Excel file
      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(filePath)], text: 'Exported $fileName');
      }
    } catch (e) {
      throw Exception('Failed to export Excel file: $e');
    }
  }

  Future<void> exportSalesReport(
    BuildContext context,
    List<Map<String, dynamic>> salesData,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sales Report'];

    const companyName = 'FlashBill Business';
    final totalSales = salesData.fold(
      0.0,
      (sum, item) => sum + (item['totalAmount'] as double),
    );

    // Header
    sheet.appendRow([TextCellValue('Sales Report')]);
    sheet.appendRow([TextCellValue('Company: $companyName')]);
    sheet.appendRow([
      TextCellValue(
        'Period: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
      ),
    ]);
    sheet.appendRow([
      TextCellValue(
        'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
      ),
    ]);
    sheet.appendRow([]); // Empty row

    // Summary
    sheet.appendRow([
      TextCellValue(
        'Total Sales: ${NumberFormat.currency(symbol: '₹').format(totalSales)}',
      ),
    ]);
    sheet.appendRow([]); // Empty row

    // Table headers
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Bill ID'),
      TextCellValue('Customer'),
      TextCellValue('Amount (₹)'),
    ]);

    // Sales data
    for (final sale in salesData) {
      sheet.appendRow([
        TextCellValue(DateFormat('dd/MM/yyyy').format(sale['date'])),
        TextCellValue(sale['id'].toString().substring(0, 8)),
        TextCellValue(sale['customerName']),
        DoubleCellValue(sale['totalAmount']),
      ]);
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/sales_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
    );
    await file.writeAsBytes(excel.encode()!);
    await Share.shareXFiles([XFile(file.path)], text: 'Sales Report');
  }

  Future<void> exportPurchaseReport(
    BuildContext context,
    List<Map<String, dynamic>> purchaseData,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Purchase Report'];

    const companyName = 'FlashBill Business';
    final totalPurchases = purchaseData.fold(
      0.0,
      (sum, item) => sum + (item['totalAmount'] as double),
    );

    // Header
    sheet.appendRow([TextCellValue('Purchase Report')]);
    sheet.appendRow([TextCellValue('Company: $companyName')]);
    sheet.appendRow([
      TextCellValue(
        'Period: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
      ),
    ]);
    sheet.appendRow([
      TextCellValue(
        'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
      ),
    ]);
    sheet.appendRow([]); // Empty row

    // Summary
    sheet.appendRow([
      TextCellValue(
        'Total Purchases: ${NumberFormat.currency(symbol: '₹').format(totalPurchases)}',
      ),
    ]);
    sheet.appendRow([]); // Empty row

    // Table headers
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Purchase ID'),
      TextCellValue('Supplier'),
      TextCellValue('Amount (₹)'),
    ]);

    // Purchase data
    for (final purchase in purchaseData) {
      sheet.appendRow([
        TextCellValue(DateFormat('dd/MM/yyyy').format(purchase['date'])),
        TextCellValue(purchase['id'].toString().substring(0, 8)),
        TextCellValue(purchase['supplierName']),
        DoubleCellValue(purchase['totalAmount']),
      ]);
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/purchase_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
    );
    await file.writeAsBytes(excel.encode()!);
    await Share.shareXFiles([XFile(file.path)], text: 'Purchase Report');
  }

  Future<void> exportExpenseReport(
    BuildContext context,
    List<Map<String, dynamic>> expenseData,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Expense Report'];

    const companyName = 'FlashBill Business';
    final totalExpenses = expenseData.fold(
      0.0,
      (sum, item) => sum + (item['amount'] as double),
    );

    // Header
    sheet.appendRow([TextCellValue('Expense Report')]);
    sheet.appendRow([TextCellValue('Company: $companyName')]);
    sheet.appendRow([
      TextCellValue(
        'Period: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
      ),
    ]);
    sheet.appendRow([
      TextCellValue(
        'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
      ),
    ]);
    sheet.appendRow([]); // Empty row

    // Summary
    sheet.appendRow([
      TextCellValue(
        'Total Expenses: ${NumberFormat.currency(symbol: '₹').format(totalExpenses)}',
      ),
    ]);
    sheet.appendRow([]); // Empty row

    // Table headers
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Description'),
      TextCellValue('Category'),
      TextCellValue('Amount (₹)'),
    ]);

    // Expense data
    for (final expense in expenseData) {
      sheet.appendRow([
        TextCellValue(DateFormat('dd/MM/yyyy').format(expense['date'])),
        TextCellValue(expense['description']),
        TextCellValue(expense['category']),
        DoubleCellValue(expense['amount']),
      ]);
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/expense_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
    );
    await file.writeAsBytes(excel.encode()!);
    await Share.shareXFiles([XFile(file.path)], text: 'Expense Report');
  }
}
