import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/report_services/report_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../services/excel_export_service.dart';
import '../base_report_page.dart';

class ExpenseReportPage extends BaseReportPage {
  const ExpenseReportPage({Key? key}) : super(key: key);

  @override
  ExpenseReportPageState createState() => ExpenseReportPageState();
}

class ExpenseReportPageState extends BaseReportPageState<ExpenseReportPage> {
  List<Map<String, dynamic>> _expenseData = [];
  String? _error;
  double _totalExpenses = 0.0;

  @override
  void onDateRangeChanged(DateTime start, DateTime end) {
    _loadExpenseReportData();
  }

  @override
  void initState() {
    super.initState();
    _loadExpenseReportData();
  }

  Future<void> _loadExpenseReportData() async {
    if (startDate == null || endDate == null) return;

    setState(() {
      isLoading = true;
      _error = null;
    });

    try {
      final reportService = ReportService();
      _expenseData = await reportService.getExpenseReport(startDate!, endDate!);
      _totalExpenses = _expenseData.fold(
        0.0,
        (sum, item) => sum + (item['amount'] as double),
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  String getPageTitle(BuildContext context) {
    return 'Expense Report';
  }

  @override
  Widget buildReportContent(BuildContext context) {
    if (_error != null) {
      return buildErrorWidget(_error!);
    }

    if (_expenseData.isEmpty) {
      return buildEmptyState(AppLocalizations.of(context)!.noDataAvailable);
    }

    final localizations = AppLocalizations.of(context)!;
    final currencyFormat = NumberFormat.currency(symbol: '₹');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      children: [
        // Summary Card
        Card(
          margin: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Expenses',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  currencyFormat.format(_totalExpenses),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expense List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: _expenseData.length,
            itemBuilder: (context, index) {
              final expense = _expenseData[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: ListTile(
                  title: Text(expense['description']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${localizations.category}: ${expense['category']}'),
                      Text(
                        '${localizations.date}: ${dateFormat.format(expense['date'])}',
                      ),
                    ],
                  ),
                  trailing: Text(
                    currencyFormat.format(expense['amount']),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                    ),
                  ),
                  onTap: () {
                    // TODO: Navigate to expense details
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Expense details for ${expense['description']}',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Future<void> exportToPDF(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final pdfService = PDFExportService();
    await pdfService.exportExpenseReport(
      context,
      _expenseData,
      startDate,
      endDate,
    );
  }

  @override
  Future<void> exportToExcel(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final excelService = ExcelExportService();
    await excelService.exportExpenseReport(
      context,
      _expenseData,
      startDate,
      endDate,
    );
  }
}
