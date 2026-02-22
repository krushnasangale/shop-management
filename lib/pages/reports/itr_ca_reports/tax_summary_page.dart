import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/itr_models/itr_models.dart';
import '../../../services/report_services/report_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../services/excel_export_service.dart';
import '../base_report_page.dart';

class TaxSummaryPage extends BaseReportPage {
  const TaxSummaryPage({Key? key}) : super(key: key);

  @override
  TaxSummaryPageState createState() => TaxSummaryPageState();
}

class TaxSummaryPageState extends BaseReportPageState<TaxSummaryPage> {
  TaxSummary? _taxSummaryData;
  String? _error;

  @override
  void onDateRangeChanged(DateTime start, DateTime end) {
    // For tax summary, we use the end date as assessment year
    _loadTaxSummaryData();
  }

  @override
  void initState() {
    super.initState();
    _loadTaxSummaryData();
  }

  Future<void> _loadTaxSummaryData() async {
    if (endDate == null) return;

    setState(() {
      isLoading = true;
      _error = null;
    });

    try {
      final reportService = ReportService();
      // Use the end date year as assessment year
      final assessmentYear = DateTime(endDate!.year, 4, 1);
      _taxSummaryData = await reportService.getTaxSummary(assessmentYear);
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
    return 'Tax Summary';
  }

  @override
  Widget buildReportContent(BuildContext context) {
    if (_error != null) {
      return buildErrorWidget(_error!);
    }

    if (_taxSummaryData == null) {
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
                    'Tax Summary',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Assessment Year: ${DateFormat('yyyy').format(_taxSummaryData!.totalIncome != 0 ? DateTime(DateTime.now().year, 4, 1) : DateTime(DateTime.now().year, 4, 1))}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          _buildTaxCard(context, 'Income Details', [
            _buildTaxRow(
              'Total Income',
              _taxSummaryData!.totalIncome,
              currencyFormat,
            ),
            _buildTaxRow(
              'Total Deductions',
              -_taxSummaryData!.totalDeductions,
              currencyFormat,
            ),
            const Divider(),
            _buildTaxRow(
              'Taxable Income',
              _taxSummaryData!.taxableIncome,
              currencyFormat,
              isBold: true,
            ),
          ]),
          const SizedBox(height: 16.0),
          _buildTaxCard(context, 'Tax Calculation', [
            _buildTaxRow(
              'Tax Liability',
              _taxSummaryData!.taxLiability,
              currencyFormat,
            ),
            _buildTaxRow('Tax Paid', -_taxSummaryData!.taxPaid, currencyFormat),
            const Divider(),
            _buildTaxRow(
              'Tax Refund/Due',
              _taxSummaryData!.taxRefund,
              currencyFormat,
              isBold: true,
            ),
          ]),
          const SizedBox(height: 16.0),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tax Compliance Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  _buildTaxComplianceStatus(_taxSummaryData!.taxRefund),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxCard(BuildContext context, String title, List<Widget> rows) {
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

  Widget _buildTaxRow(
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
              color: amount < 0
                  ? Colors.red
                  : (amount > 0 ? Colors.green : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxComplianceStatus(double taxRefund) {
    String status;
    Color statusColor;
    IconData statusIcon;

    if (taxRefund > 0) {
      status = 'Tax Refund Due';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (taxRefund < 0) {
      status = 'Tax Payment Due';
      statusColor = Colors.red;
      statusIcon = Icons.warning;
    } else {
      status = 'Tax Compliant';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    }

    return Row(
      children: [
        Icon(statusIcon, color: statusColor),
        const SizedBox(width: 8.0),
        Text(
          status,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 16.0,
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
    if (_taxSummaryData == null) return;

    final pdfService = PDFExportService();
    await pdfService.exportTaxSummary(context, _taxSummaryData!);
  }

  @override
  Future<void> exportToExcel(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (_taxSummaryData == null) return;

    final excelService = ExcelExportService();
    await excelService.exportTaxSummary(context, _taxSummaryData!);
  }
}
