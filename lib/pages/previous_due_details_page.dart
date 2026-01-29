import 'package:flashbill/pages/billing/view_existing_bill_details.dart';
import 'package:flutter/material.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/l10n/app_localizations.dart';

class PreviousDueDetailsPage extends StatelessWidget {
  final Map<String, dynamic> payment;

  const PreviousDueDetailsPage({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFullyPaid = payment['isFullyPaid'] as bool;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.previousDue ?? 'Previous Due'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isFullyPaid
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFullyPaid
                      ? Colors.green.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isFullyPaid ? Icons.check_circle : Icons.pending,
                    size: 48,
                    color: isFullyPaid ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isFullyPaid
                        ? (loc?.collected ?? 'Collected')
                        : (loc?.pending ?? 'Pending'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isFullyPaid ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${payment['previousDueAmount']}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isFullyPaid
                          ? Colors.green[700]!
                          : Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Customer Information
            Text(
              loc?.customerInformation ?? 'Customer Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.grey[100] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800]! : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    Icons.person,
                    loc?.customerName ?? 'Customer Name',
                    payment['customerName'],
                    isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Previous Due Details
            Text(
              loc?.previousDue ?? 'Previous Due',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.grey[100] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800]! : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    Icons.history,
                    loc?.previousDue ?? 'Previous Due',
                    '₹${payment['previousDueAmount']}',
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.calendar_today,
                    loc?.billDate ?? 'Bill Date',
                    payment['billDate'],
                    isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToBillDetails(context),
                icon: const Icon(Icons.receipt_long),
                label: Text(loc?.viewBillDetails ?? 'View Bill Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.purple[600]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[100] : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToBillDetails(BuildContext context) {
    AppNavigator.push(
      context,
      ViewBillDetailsScreen(
        billId: payment['billId'],
        billDate: payment['billDate'],
        customerName: payment['customerName'],
        customerMobile: '',
        customerVehicle: '',
        totalAmount: payment['totalAmount'],
        totalAmountPaid: payment['isFullyPaid'],
        amountPaid: payment['amountPaid'],
        amountRemaining: payment['amountRemaining'],
        products: [],
        nextPaymentDate: '',
        previousDueAmount: payment['previousDueAmount'],
        previousDueDescription: '',
      ),
    );
  }
}
