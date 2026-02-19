import 'dart:ui';

import 'package:flashbill/pages/billing/bills.dart';
import 'package:flutter/material.dart';

String getMonthName(int month) {
  switch (month) {
    case 1:
      return 'January';
    case 2:
      return 'February';
    case 3:
      return 'March';
    case 4:
      return 'April';
    case 5:
      return 'May';
    case 6:
      return 'June';
    case 7:
      return 'July';
    case 8:
      return 'August';
    case 9:
      return 'September';
    case 10:
      return 'October';
    case 11:
      return 'November';
    case 12:
      return 'December';
    default:
      return '';
  }
}

Color getOtherDueAmountColor(double dueAmount, double paidAmount) {
  if (dueAmount == paidAmount) {
    return const Color(0x1981C784); // Light Green 10% opacity
  } else if (paidAmount > 0 && dueAmount > 0) {
    return const Color(0x19FFB74D); // Light Orange 10% opacity
  } else {
    return const Color(0x19EF5350); // Light Red 10% opacity
  }
}

Color getStatusColor(PaymentFilter status) {
  switch (status) {
    case PaymentFilter.paid:
      return Colors.green;
    case PaymentFilter.partial:
      return Colors.orange;
    case PaymentFilter.unpaid:
      return Colors.red;
    case PaymentFilter.previousDue:
      return Colors.blue;
    default:
      return Colors.grey;
  }
}
