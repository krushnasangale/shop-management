import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Unicode PDF theme so currency symbols (₹, €, etc.) render instead of boxes.
class PdfFonts {
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> theme() async {
    if (_theme != null) return _theme!;
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    _theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: regular,
      boldItalic: bold,
    );
    return _theme!;
  }
}
