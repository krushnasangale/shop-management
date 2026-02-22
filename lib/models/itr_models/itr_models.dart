import 'package:cloud_firestore/cloud_firestore.dart';

/// Base class for ITR data
class ITRData {
  final String id;
  final String userId;
  final DateTime assessmentYear;
  final DateTime createdAt;
  final DateTime updatedAt;

  ITRData({
    required this.id,
    required this.userId,
    required this.assessmentYear,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ITRData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ITRData(
      id: doc.id,
      userId: data['userId'] ?? '',
      assessmentYear: (data['assessmentYear'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'assessmentYear': Timestamp.fromDate(assessmentYear),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

/// Profit and Loss Statement data
class ProfitLossStatement {
  final String id;
  final String itrId;
  final double totalRevenue;
  final double totalExpenses;
  final double grossProfit;
  final double netProfit;
  final DateTime periodStart;
  final DateTime periodEnd;

  ProfitLossStatement({
    required this.id,
    required this.itrId,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.grossProfit,
    required this.netProfit,
    required this.periodStart,
    required this.periodEnd,
  });

  factory ProfitLossStatement.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProfitLossStatement(
      id: doc.id,
      itrId: data['itrId'] ?? '',
      totalRevenue: (data['totalRevenue'] ?? 0.0).toDouble(),
      totalExpenses: (data['totalExpenses'] ?? 0.0).toDouble(),
      grossProfit: (data['grossProfit'] ?? 0.0).toDouble(),
      netProfit: (data['netProfit'] ?? 0.0).toDouble(),
      periodStart: (data['periodStart'] as Timestamp).toDate(),
      periodEnd: (data['periodEnd'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itrId': itrId,
      'totalRevenue': totalRevenue,
      'totalExpenses': totalExpenses,
      'grossProfit': grossProfit,
      'netProfit': netProfit,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
    };
  }
}

/// Balance Sheet data
class BalanceSheet {
  final String id;
  final String itrId;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final DateTime asOfDate;

  BalanceSheet({
    required this.id,
    required this.itrId,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.asOfDate,
  });

  factory BalanceSheet.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BalanceSheet(
      id: doc.id,
      itrId: data['itrId'] ?? '',
      totalAssets: (data['totalAssets'] ?? 0.0).toDouble(),
      totalLiabilities: (data['totalLiabilities'] ?? 0.0).toDouble(),
      netWorth: (data['netWorth'] ?? 0.0).toDouble(),
      asOfDate: (data['asOfDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itrId': itrId,
      'totalAssets': totalAssets,
      'totalLiabilities': totalLiabilities,
      'netWorth': netWorth,
      'asOfDate': Timestamp.fromDate(asOfDate),
    };
  }
}

/// GST Report data
class GSTReport {
  final String id;
  final String itrId;
  final double totalGSTCollected;
  final double totalGSTPaid;
  final double netGSTLiability;
  final DateTime periodStart;
  final DateTime periodEnd;

  GSTReport({
    required this.id,
    required this.itrId,
    required this.totalGSTCollected,
    required this.totalGSTPaid,
    required this.netGSTLiability,
    required this.periodStart,
    required this.periodEnd,
  });

  factory GSTReport.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return GSTReport(
      id: doc.id,
      itrId: data['itrId'] ?? '',
      totalGSTCollected: (data['totalGSTCollected'] ?? 0.0).toDouble(),
      totalGSTPaid: (data['totalGSTPaid'] ?? 0.0).toDouble(),
      netGSTLiability: (data['netGSTLiability'] ?? 0.0).toDouble(),
      periodStart: (data['periodStart'] as Timestamp).toDate(),
      periodEnd: (data['periodEnd'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itrId': itrId,
      'totalGSTCollected': totalGSTCollected,
      'totalGSTPaid': totalGSTPaid,
      'netGSTLiability': netGSTLiability,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
    };
  }
}

/// Tax Summary data
class TaxSummary {
  final String id;
  final String itrId;
  final double totalIncome;
  final double totalDeductions;
  final double taxableIncome;
  final double taxLiability;
  final double taxPaid;
  final double taxRefund;

  TaxSummary({
    required this.id,
    required this.itrId,
    required this.totalIncome,
    required this.totalDeductions,
    required this.taxableIncome,
    required this.taxLiability,
    required this.taxPaid,
    required this.taxRefund,
  });

  factory TaxSummary.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TaxSummary(
      id: doc.id,
      itrId: data['itrId'] ?? '',
      totalIncome: (data['totalIncome'] ?? 0.0).toDouble(),
      totalDeductions: (data['totalDeductions'] ?? 0.0).toDouble(),
      taxableIncome: (data['taxableIncome'] ?? 0.0).toDouble(),
      taxLiability: (data['taxLiability'] ?? 0.0).toDouble(),
      taxPaid: (data['taxPaid'] ?? 0.0).toDouble(),
      taxRefund: (data['taxRefund'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itrId': itrId,
      'totalIncome': totalIncome,
      'totalDeductions': totalDeductions,
      'taxableIncome': taxableIncome,
      'taxLiability': taxLiability,
      'taxPaid': taxPaid,
      'taxRefund': taxRefund,
    };
  }
}
