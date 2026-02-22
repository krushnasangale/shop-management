import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/itr_models/itr_models.dart';
import '../../../services/report_services/report_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../services/excel_export_service.dart';
import '../base_report_page.dart';

class GSTReportPage extends BaseReportPage {
  const GSTReportPage({Key? key}) : super(key: key);

  @override
  GSTReportPageState createState() => GSTReportPageState();
}

class GSTReportPageState extends BaseReportPageState<GSTReportPage> {
  GSTReport? _gstReportData;
  String? _error;

  @override
  void onDateRangeChanged(DateTime start, DateTime end) {
    _loadGSTReportData();
  }

  @override
  void initState() {
    super.initState();
    _loadGSTReportData();
  }

  Future<void> _loadGSTReportData() async {
    if (startDate == null || endDate == null) return;

    setState(() {
      isLoading = true;
      _error = null;
    });

    try {
      final reportService = ReportService();
      _gstReportData = await reportService.getGSTReport(startDate!, endDate!);
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
    return 'GST Report';
  }

  @override
  Widget buildReportContent(BuildContext context) {
    if (_error != null) {
      return buildErrorWidget(_error!);
    }

    if (_gstReportData == null) {
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
                    'GST Report',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    '${localizations.period}: ${DateFormat('dd/MM/yyyy').format(_gstReportData!.periodStart)} - ${DateFormat('dd/MM/yyyy').format(_gstReportData!.periodEnd)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          _buildGSTSummaryCard(context, 'GST Summary', [
            _buildGSTRow(
              'Total GST Collected',
              _gstReportData!.totalGSTCollected,
              currencyFormat,
            ),
            _buildGSTRow(
              'Total GST Paid',
              -_gstReportData!.totalGSTPaid,
              currencyFormat,
            ),
            const Divider(),
            _buildGSTRow(
              'Net GST Liability',
              _gstReportData!.netGSTLiability,
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
                    'GST Compliance Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  _buildComplianceStatus(_gstReportData!.netGSTLiability),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGSTSummaryCard(
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

  Widget _buildGSTRow(
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

  Widget _buildComplianceStatus(double netLiability) {
    String status;
    Color statusColor;
    IconData statusIcon;

    if (netLiability > 0) {
      status = 'GST Payable';
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else if (netLiability < 0) {
      status = 'GST Refund Due';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      status = 'GST Compliant';
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
    if (_gstReportData == null) return;

    final pdfService = PDFExportService();
    await pdfService.exportGSTReport(context, _gstReportData!);
  }

  @override
  Future<void> exportToExcel(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (_gstReportData == null) return;

    final excelService = ExcelExportService();
    await excelService.exportGSTReport(context, _gstReportData!);
  }
}
