import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/itr_models/itr_models.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  /// Get ITR data for current user
  Future<List<ITRData>> getITRData() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('itr_data')
          .where('userId', isEqualTo: currentUserId)
          .orderBy('assessmentYear', descending: true)
          .get();

      return snapshot.docs.map((doc) => ITRData.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch ITR data: $e');
    }
  }

  /// Get Profit & Loss statement for a date range
  Future<ProfitLossStatement?> getProfitLossStatement(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // Fetch sales data
      QuerySnapshot salesSnapshot = await _firestore
          .collection('bills')
          .where('userId', isEqualTo: currentUserId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double totalRevenue = 0.0;
      for (var doc in salesSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalRevenue += (data['totalAmount'] ?? 0.0).toDouble();
      }

      // Fetch purchase/expense data
      QuerySnapshot purchaseSnapshot = await _firestore
          .collection('purchases')
          .where('userId', isEqualTo: currentUserId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double totalExpenses = 0.0;
      for (var doc in purchaseSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalExpenses += (data['totalAmount'] ?? 0.0).toDouble();
      }

      // Fetch additional expenses
      QuerySnapshot expenseSnapshot = await _firestore
          .collection('expenses')
          .where('userId', isEqualTo: currentUserId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      for (var doc in expenseSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalExpenses += (data['amount'] ?? 0.0).toDouble();
      }

      double grossProfit = totalRevenue - totalExpenses;
      double netProfit = grossProfit; // For now, assuming no other deductions

      return ProfitLossStatement(
        id: 'temp_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}',
        itrId: '',
        totalRevenue: totalRevenue,
        totalExpenses: totalExpenses,
        grossProfit: grossProfit,
        netProfit: netProfit,
        periodStart: startDate,
        periodEnd: endDate,
      );
    } catch (e) {
      throw Exception('Failed to generate Profit & Loss statement: $e');
    }
  }

  /// Get Balance Sheet data
  Future<BalanceSheet?> getBalanceSheet(DateTime asOfDate) async {
    try {
      // This is a simplified implementation
      // In a real scenario, you'd calculate assets, liabilities, etc. from various collections
      double totalAssets = 0.0;
      double totalLiabilities = 0.0;

      // For now, return a basic balance sheet
      return BalanceSheet(
        id: 'temp_balance_${asOfDate.millisecondsSinceEpoch}',
        itrId: '',
        totalAssets: totalAssets,
        totalLiabilities: totalLiabilities,
        netWorth: totalAssets - totalLiabilities,
        asOfDate: asOfDate,
      );
    } catch (e) {
      throw Exception('Failed to generate Balance Sheet: $e');
    }
  }

  /// Get GST Report for a date range
  Future<GSTReport?> getGSTReport(DateTime startDate, DateTime endDate) async {
    try {
      // Simplified GST calculation
      // In reality, you'd need to track GST separately in transactions
      double totalGSTCollected = 0.0;
      double totalGSTPaid = 0.0;

      return GSTReport(
        id: 'temp_gst_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}',
        itrId: '',
        totalGSTCollected: totalGSTCollected,
        totalGSTPaid: totalGSTPaid,
        netGSTLiability: totalGSTCollected - totalGSTPaid,
        periodStart: startDate,
        periodEnd: endDate,
      );
    } catch (e) {
      throw Exception('Failed to generate GST Report: $e');
    }
  }

  /// Get Tax Summary
  Future<TaxSummary?> getTaxSummary(DateTime assessmentYear) async {
    try {
      // Simplified tax calculation
      double totalIncome = 0.0;
      double totalDeductions = 0.0;
      double taxableIncome = totalIncome - totalDeductions;
      double taxLiability = _calculateTaxLiability(taxableIncome);
      double taxPaid = 0.0; // Would come from actual tax payments
      double taxRefund = taxPaid - taxLiability;

      return TaxSummary(
        id: 'temp_tax_${assessmentYear.millisecondsSinceEpoch}',
        itrId: '',
        totalIncome: totalIncome,
        totalDeductions: totalDeductions,
        taxableIncome: taxableIncome,
        taxLiability: taxLiability,
        taxPaid: taxPaid,
        taxRefund: taxRefund,
      );
    } catch (e) {
      throw Exception('Failed to generate Tax Summary: $e');
    }
  }

  /// Calculate tax liability (simplified Indian tax slabs)
  double _calculateTaxLiability(double taxableIncome) {
    if (taxableIncome <= 250000) return 0.0;
    if (taxableIncome <= 500000) return (taxableIncome - 250000) * 0.05;
    if (taxableIncome <= 1000000)
      return 12500 + (taxableIncome - 500000) * 0.20;
    return 12500 + 100000 + (taxableIncome - 1000000) * 0.30;
  }

  /// Get sales report data
  Future<List<Map<String, dynamic>>> getSalesReport(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('bills')
          .where('userId', isEqualTo: currentUserId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'date': (data['date'] as Timestamp).toDate(),
          'customerName': data['customerName'] ?? '',
          'totalAmount': (data['totalAmount'] ?? 0.0).toDouble(),
          'items': data['items'] ?? [],
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch sales report: $e');
    }
  }

  /// Get purchase report data
  Future<List<Map<String, dynamic>>> getPurchaseReport(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('purchases')
          .where('userId', isEqualTo: currentUserId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'date': (data['date'] as Timestamp).toDate(),
          'supplierName': data['supplierName'] ?? '',
          'totalAmount': (data['totalAmount'] ?? 0.0).toDouble(),
          'items': data['items'] ?? [],
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch purchase report: $e');
    }
  }

  /// Get expense report data
  Future<List<Map<String, dynamic>>> getExpenseReport(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('expenses')
          .where('userId', isEqualTo: currentUserId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'date': (data['date'] as Timestamp).toDate(),
          'description': data['description'] ?? '',
          'amount': (data['amount'] ?? 0.0).toDouble(),
          'category': data['category'] ?? '',
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch expense report: $e');
    }
  }
}
