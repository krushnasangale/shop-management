import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';

abstract class BaseReportPage extends StatefulWidget {
  const BaseReportPage({Key? key}) : super(key: key);

  @override
  BaseReportPageState createState();
}

abstract class BaseReportPageState<T extends BaseReportPage> extends State<T> {
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set default date range to current financial year
    _setDefaultDateRange();
  }

  void _setDefaultDateRange() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // Financial year starts from April 1st
    if (currentMonth >= 4) {
      startDate = DateTime(currentYear, 4, 1);
      endDate = DateTime(currentYear + 1, 3, 31);
    } else {
      startDate = DateTime(currentYear - 1, 4, 1);
      endDate = DateTime(currentYear, 3, 31);
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      onDateRangeChanged(picked.start, picked.end);
    }
  }

  void onDateRangeChanged(DateTime start, DateTime end) {
    // Override in subclasses to handle date range changes
  }

  Widget buildDateRangeSelector(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.selectDateRange,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8.0),
            Row(
              children: [
                Expanded(
                  child: Text(
                    startDate != null
                        ? '${localizations.from}: ${dateFormat.format(startDate!)}'
                        : localizations.selectStartDate,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    endDate != null
                        ? '${localizations.to}: ${dateFormat.format(endDate!)}'
                        : localizations.selectEndDate,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => _selectDateRange(context),
                  icon: const Icon(Icons.calendar_today),
                  tooltip: localizations.selectDateRange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLoadingIndicator() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48.0, color: Colors.red),
          const SizedBox(height: 16.0),
          Text(
            error,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 48.0, color: Colors.grey),
          const SizedBox(height: 16.0),
          Text(
            message,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(getPageTitle(context)),
        actions: [
          IconButton(
            onPressed: () => _selectDateRange(context),
            icon: const Icon(Icons.date_range),
            tooltip: AppLocalizations.of(context)!.selectDateRange,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'pdf') {
                await _exportToPDF();
              } else if (value == 'excel') {
                await _exportToExcel();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'pdf',
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.exportToPDF),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'excel',
                child: Row(
                  children: [
                    const Icon(Icons.table_chart, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.exportToExcel),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.download),
            tooltip: AppLocalizations.of(context)!.exportReport,
          ),
        ],
      ),
      body: Column(
        children: [
          buildDateRangeSelector(context),
          Expanded(
            child: isLoading
                ? buildLoadingIndicator()
                : buildReportContent(context),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPDF() async {
    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.selectDateRangeFirst),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      await exportToPDF(context, startDate!, endDate!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.exportSuccessful),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.exportFailed}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _exportToExcel() async {
    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.selectDateRangeFirst),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      await exportToExcel(context, startDate!, endDate!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.exportSuccessful),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.exportFailed}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  String getPageTitle(BuildContext context);

  Widget buildReportContent(BuildContext context);

  Future<void> exportToPDF(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
  );

  Future<void> exportToExcel(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
  );
}
