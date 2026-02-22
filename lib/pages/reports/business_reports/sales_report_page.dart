import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/report_services/report_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../services/excel_export_service.dart';
import '../base_report_page.dart';

class SalesReportPage extends BaseReportPage {
  const SalesReportPage({Key? key}) : super(key: key);

  @override
  SalesReportPageState createState() => SalesReportPageState();
}

class SalesReportPageState extends BaseReportPageState<SalesReportPage> {
  List<Map<String, dynamic>> _salesData = [];
  String? _error;
  double _totalSales = 0.0;

  @override
  void onDateRangeChanged(DateTime start, DateTime end) {
    _loadSalesReportData();
  }

  @override
  void initState() {
    super.initState();
    _loadSalesReportData();
  }

  Future<void> _loadSalesReportData() async {
    if (startDate == null || endDate == null) return;

    setState(() {
      isLoading = true;
      _error = null;
    });

    try {
      final reportService = ReportService();
      _salesData = await reportService.getSalesReport(startDate!, endDate!);
      _totalSales = _salesData.fold(
        0.0,
        (sum, item) => sum + (item['totalAmount'] as double),
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
    return 'Sales Report';
  }

  @override
  Widget buildReportContent(BuildContext context) {
    if (_error != null) {
      return buildErrorWidget(_error!);
    }

    if (_salesData.isEmpty) {
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
                  'Total Sales',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  currencyFormat.format(_totalSales),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Sales List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: _salesData.length,
            itemBuilder: (context, index) {
              final sale = _salesData[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: ListTile(
                  title: Text('Bill #${sale['id'].toString().substring(0, 8)}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${localizations.customer}: ${sale['customerName']}',
                      ),
                      Text(
                        '${localizations.date}: ${dateFormat.format(sale['date'])}',
                      ),
                    ],
                  ),
                  trailing: Text(
                    currencyFormat.format(sale['totalAmount']),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                    ),
                  ),
                  onTap: () {
                    // TODO: Navigate to bill details
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Bill details for ${sale['id']}')),
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
    await pdfService.exportSalesReport(context, _salesData, startDate, endDate);
  }

  @override
  Future<void> exportToExcel(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final excelService = ExcelExportService();
    await excelService.exportSalesReport(
      context,
      _salesData,
      startDate,
      endDate,
    );
  }
}
