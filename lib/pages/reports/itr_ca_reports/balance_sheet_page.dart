import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/itr_models/itr_models.dart';
import '../../../services/report_services/report_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../services/excel_export_service.dart';
import '../base_report_page.dart';

class BalanceSheetPage extends BaseReportPage {
  const BalanceSheetPage({Key? key}) : super(key: key);

  @override
  BalanceSheetPageState createState() => BalanceSheetPageState();
}

class BalanceSheetPageState extends BaseReportPageState<BalanceSheetPage> {
  BalanceSheet? _balanceSheetData;
  String? _error;

  @override
  void onDateRangeChanged(DateTime start, DateTime end) {
    _loadBalanceSheetData();
  }

  @override
  void initState() {
    super.initState();
    _loadBalanceSheetData();
  }

  Future<void> _loadBalanceSheetData() async {
    if (endDate == null) return;

    setState(() {
      isLoading = true;
      _error = null;
    });

    try {
      final reportService = ReportService();
      _balanceSheetData = await reportService.getBalanceSheet(endDate!);
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
    return AppLocalizations.of(context)!.balanceSheet;
  }

  @override
  Widget buildReportContent(BuildContext context) {
    if (_error != null) {
      return buildErrorWidget(_error!);
    }

    if (_balanceSheetData == null) {
      return buildEmptyState(AppLocalizations.of(context)!.noDataAvailable);
    }

    final localizations = AppLocalizations.of(context)!;
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.balanceSheet,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    '${localizations.asOf}: ${DateFormat('dd/MM/yyyy').format(_balanceSheetData!.asOfDate)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          _buildBalanceSheetSection(context, 'Assets', [
            _buildBalanceSheetRow(
              'Total Assets',
              _balanceSheetData!.totalAssets,
              currencyFormat,
            ),
          ]),
          const SizedBox(height: 16.0),
          _buildBalanceSheetSection(context, 'Liabilities', [
            _buildBalanceSheetRow(
              'Total Liabilities',
              -_balanceSheetData!.totalLiabilities,
              currencyFormat,
            ),
          ]),
          const SizedBox(height: 16.0),
          _buildBalanceSheetSection(context, 'Equity', [
            _buildBalanceSheetRow(
              'Net Worth',
              _balanceSheetData!.netWorth,
              currencyFormat,
              isBold: true,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildBalanceSheetSection(
    BuildContext context,
    String title,
    List<Widget> rows,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12.0),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceSheetRow(
    String label,
    double amount,
    NumberFormat format, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 16.0,
            ),
          ),
          Text(
            format.format(amount.abs()),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 16.0,
              color: amount < 0 ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> exportToPDF(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (_balanceSheetData == null) return;

    final pdfService = PDFExportService();
    await pdfService.exportBalanceSheet(context, _balanceSheetData!);
  }

  @override
  Future<void> exportToExcel(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (_balanceSheetData == null) return;

    final excelService = ExcelExportService();
    await excelService.exportBalanceSheet(context, _balanceSheetData!);
  }
}
