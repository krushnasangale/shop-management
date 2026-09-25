import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Unicode PDF theme so currency symbols (₹, €, etc.) render instead of boxes.
class PdfFonts {
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> theme() async {
    if (_theme != null) return _theme!;
    _theme = await _loadFromAssets() ??
        await _loadFromGoogle() ??
        pw.ThemeData.base();
    return _theme!;
  }

  static Future<pw.ThemeData?> _loadFromAssets() async {
    try {
      final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
      );
      return pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: regular,
        boldItalic: bold,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<pw.ThemeData?> _loadFromGoogle() async {
    try {
      final regular = await PdfGoogleFonts.notoSansRegular();
      final bold = await PdfGoogleFonts.notoSansBold();
      return pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: regular,
        boldItalic: bold,
      );
    } catch (_) {
      return null;
    }
  }
}
