import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'itr_ca_reports/profit_loss_statement_page.dart';
import 'itr_ca_reports/balance_sheet_page.dart';
import 'itr_ca_reports/gst_report_page.dart';
import 'itr_ca_reports/tax_summary_page.dart';
import 'business_reports/sales_report_page.dart';
import 'business_reports/purchase_report_page.dart';
import 'business_reports/expense_report_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.reports)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildReportSection(context, 'ITR for CA', [
            _buildReportTile(
              context,
              localizations.profitLossStatement,
              'View profit and loss statement for selected period',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfitLossStatementPage(),
                ),
              ),
            ),
            _buildReportTile(
              context,
              localizations.balanceSheet,
              'View balance sheet as of selected date',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BalanceSheetPage(),
                ),
              ),
            ),
            _buildReportTile(
              context,
              'GST Report',
              'View GST collection and payment details',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GSTReportPage()),
              ),
            ),
            _buildReportTile(
              context,
              'Tax Summary',
              'View tax calculation and compliance status',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TaxSummaryPage()),
              ),
            ),
            // Add more ITR reports here as they are implemented
          ]),
          const SizedBox(height: 24.0),
          _buildReportSection(context, 'Business Reports', [
            // Add business reports here as they are implemented
            _buildReportTile(
              context,
              'Sales Report',
              'View detailed sales report',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SalesReportPage(),
                ),
              ),
            ),
            _buildReportTile(
              context,
              'Purchase Report',
              'View detailed purchase report',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PurchaseReportPage(),
                ),
              ),
            ),
            _buildReportTile(
              context,
              'Expense Report',
              'View detailed expense report',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExpenseReportPage(),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildReportSection(
    BuildContext context,
    String title,
    List<Widget> reports,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...reports,
      ],
    );
  }

  Widget _buildReportTile(
    BuildContext context,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
