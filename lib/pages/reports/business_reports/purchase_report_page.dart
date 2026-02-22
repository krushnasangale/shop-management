import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/report_services/report_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../services/excel_export_service.dart';
import '../base_report_page.dart';

class PurchaseReportPage extends BaseReportPage {
  const PurchaseReportPage({Key? key}) : super(key: key);

  @override
  PurchaseReportPageState createState() => PurchaseReportPageState();
}

class PurchaseReportPageState extends BaseReportPageState<PurchaseReportPage> {
  List<Map<String, dynamic>> _purchaseData = [];
  String? _error;
  double _totalPurchases = 0.0;

  @override
  void onDateRangeChanged(DateTime start, DateTime end) {
    _loadPurchaseReportData();
  }

  @override
  void initState() {
    super.initState();
    _loadPurchaseReportData();
  }

  Future<void> _loadPurchaseReportData() async {
    if (startDate == null || endDate == null) return;

    setState(() {
      isLoading = true;
      _error = null;
    });

    try {
      final reportService = ReportService();
      _purchaseData = await reportService.getPurchaseReport(
        startDate!,
        endDate!,
      );
      _totalPurchases = _purchaseData.fold(
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
    return 'Purchase Report';
  }

  @override
  Widget buildReportContent(BuildContext context) {
    if (_error != null) {
      return buildErrorWidget(_error!);
    }

    if (_purchaseData.isEmpty) {
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
                  'Total Purchases',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  currencyFormat.format(_totalPurchases),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Purchase List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: _purchaseData.length,
            itemBuilder: (context, index) {
              final purchase = _purchaseData[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: ListTile(
                  title: Text(
                    'Purchase #${purchase['id'].toString().substring(0, 8)}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${localizations.supplier}: ${purchase['supplierName']}',
                      ),
                      Text(
                        '${localizations.date}: ${dateFormat.format(purchase['date'])}',
                      ),
                    ],
                  ),
                  trailing: Text(
                    currencyFormat.format(purchase['totalAmount']),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                    ),
                  ),
                  onTap: () {
                    // TODO: Navigate to purchase details
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Purchase details for ${purchase['id']}'),
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
    await pdfService.exportPurchaseReport(
      context,
      _purchaseData,
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
    await excelService.exportPurchaseReport(
      context,
      _purchaseData,
      startDate,
      endDate,
    );
  }
}
