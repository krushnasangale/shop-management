import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/itr_models/itr_models.dart';
import '../../../services/report_services/report_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../services/excel_export_service.dart';
import '../base_report_page.dart';

class ProfitLossStatementPage extends BaseReportPage {
  const ProfitLossStatementPage({Key? key}) : super(key: key);

  @override
  ProfitLossStatementPageState createState() => ProfitLossStatementPageState();
}

class ProfitLossStatementPageState
    extends BaseReportPageState<ProfitLossStatementPage> {
  ProfitLossStatement? _profitLossData;
  String? _error;

  @override
  void onDateRangeChanged(DateTime start, DateTime end) {
    _loadProfitLossData();
  }

  @override
  void initState() {
    super.initState();
    _loadProfitLossData();
  }

  Future<void> _loadProfitLossData() async {
    if (startDate == null || endDate == null) return;

    setState(() {
      isLoading = true;
      _error = null;
    });

    try {
      final reportService = ReportService();
      _profitLossData = await reportService.getProfitLossStatement(
        startDate!,
        endDate!,
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
    return AppLocalizations.of(context)!.profitLossStatement;
  }

  @override
  Widget buildReportContent(BuildContext context) {
    if (_error != null) {
      return buildErrorWidget(_error!);
    }

    if (_profitLossData == null) {
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
                    localizations.profitLossStatement,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    '${localizations.period}: ${DateFormat('dd/MM/yyyy').format(_profitLossData!.periodStart)} - ${DateFormat('dd/MM/yyyy').format(_profitLossData!.periodEnd)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          _buildFinancialRow(
            localizations.totalRevenue,
            _profitLossData!.totalRevenue,
            currencyFormat,
          ),
          _buildFinancialRow(
            localizations.totalExpenses,
            -_profitLossData!.totalExpenses,
            currencyFormat,
          ),
          const Divider(),
          _buildFinancialRow(
            localizations.grossProfit,
            _profitLossData!.grossProfit,
            currencyFormat,
            isBold: true,
          ),
          const SizedBox(height: 16.0),
          _buildFinancialRow(
            localizations.netProfit,
            _profitLossData!.netProfit,
            currencyFormat,
            isBold: true,
            isLarge: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(
    String label,
    double amount,
    NumberFormat format, {
    bool isBold = false,
    bool isLarge = false,
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
              fontSize: isLarge ? 18.0 : 16.0,
            ),
          ),
          Text(
            format.format(amount.abs()),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isLarge ? 18.0 : 16.0,
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
    if (_profitLossData == null) return;

    final pdfService = PDFExportService();
    await pdfService.exportProfitLossStatement(context, _profitLossData!);
  }

  @override
  Future<void> exportToExcel(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (_profitLossData == null) return;

    final excelService = ExcelExportService();
    await excelService.exportProfitLossStatement(context, _profitLossData!);
  }
}
