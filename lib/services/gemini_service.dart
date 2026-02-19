import 'dart:convert';
import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for interacting with Google Gemini AI API
/// Handles invoice scanning and data extraction
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  late GenerativeModel _model;
  bool _isInitialized = false;

  /// Initialize the Gemini service with API key from .env
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Firebase AI doesn't need API key from .env
      // It uses Firebase authentication automatically
      final vertexInstance = FirebaseAI.vertexAI(auth: FirebaseAuth.instance);
      _model = vertexInstance.generativeModel(
        model: 'gemini-2.0-flash-exp',
        generationConfig: GenerationConfig(
          temperature: 0.1, // Low temperature for consistent, factual output
          topK: 32,
          topP: 1,
          maxOutputTokens: 2048,
        ),
        systemInstruction: Content.system(
          'You are an expert accountant assistant for an electronics shop in India. '
          'Your only job is to extract purchase invoice data accurately and return it as valid JSON. '
          'Focus on Indian bill formats (GST invoices, handwritten bills, etc.). '
          'Be precise with numbers and product names.',
        ),
      );

      _isInitialized = true;
      print('✅ Gemini Service initialized successfully');
    } catch (e) {
      print('❌ Error initializing Gemini Service: $e');
      rethrow;
    }
  }

  /// Extract invoice data from an image or PDF
  /// Returns structured JSON with supplier, date, products, and total
  Future<Map<String, dynamic>> extractInvoiceData({
    String? imagePath,
    String? pdfText,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Retry logic with exponential backoff for rate limiting
    int maxRetries = 3;
    int retryDelay = 2; // Start with 2 seconds

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final prompt = _buildPrompt();
        List<Part> parts = [TextPart(prompt)];

        // Add image if provided
        if (imagePath != null) {
          final imageBytes = await File(imagePath).readAsBytes();
          parts.add(InlineDataPart('image/jpeg', imageBytes));
        }

        // Add PDF text if provided (limit to 12000 chars for multi-page invoices)
        if (pdfText != null && pdfText.isNotEmpty) {
          final limitedText = pdfText.length > 12000
              ? pdfText.substring(0, 12000)
              : pdfText;
          parts.add(TextPart('\n\nExtracted text from PDF:\n$limitedText'));
        }

        final content = Content.multi(parts);
        final response = await _model.generateContent([content]);

        if (response.text == null || response.text!.isEmpty) {
          throw Exception('Gemini returned empty response');
        }

        // Parse JSON from response
        final jsonData = _extractJsonFromResponse(response.text!);
        return jsonData;
      } catch (e) {
        // Handle Gemini API errors
        final errorMessage = e.toString();

        // Check if it's a rate limit error and we have retries left
        if ((errorMessage.contains('429') ||
                errorMessage.contains('RESOURCE_EXHAUSTED')) &&
            attempt < maxRetries) {
          print(
            'Rate limit hit, retrying in $retryDelay seconds... (attempt ${attempt + 1}/$maxRetries)',
          );
          await Future.delayed(Duration(seconds: retryDelay));
          retryDelay *= 2; // Exponential backoff: 2s, 4s, 8s
          continue; // Retry
        }

        // If no more retries or different error, throw
        if (errorMessage.contains('429') ||
            errorMessage.contains('RESOURCE_EXHAUSTED')) {
          throw Exception(
            'Too many requests. Please wait a moment and try again.',
          );
        } else if (errorMessage.contains('quota') ||
            errorMessage.contains('QUOTA_EXCEEDED')) {
          throw Exception(
            'Daily quota exceeded. Please try again tomorrow or upgrade to paid tier.',
          );
        } else {
          print('Error in extractInvoiceData: $e');
          throw Exception('Gemini API Error: $errorMessage');
        }
      }
    }

    // Should never reach here, but just in case
    throw Exception('Failed to process invoice after $maxRetries retries');
  }

  /// Build the prompt for invoice extraction
  String _buildPrompt() {
    return '''
Extract purchase invoice data from this image or text.
Return ONLY valid JSON with this EXACT structure (no markdown, no explanation):

{
  "supplierName": "ABC Electronics",
  "date": "19/02/2026",
  "products": [
    {"name": "LED Bulb 9W", "quantity": 50, "price": 45.00, "unit": "Pcs"},
    {"name": "Wire 2.5mm 100m", "quantity": 10, "price": 1250.00, "unit": "Roll"}
  ],
  "totalAmount": 14750.00
}

EXTRACTION RULES:
1. **supplierName**: Extract the business/supplier name (usually at top of bill). If not found, use "Unknown Supplier"
2. **date**: Use DD/MM/YYYY format. If unclear, try to infer from context or use today's date
3. **products**: Array of items with:
   - name: Full product name/description
   - quantity: Number of units purchased (integer)
   - price: Unit price per item (NOT line total), as decimal
   - unit: Unit of measurement (Pcs, Kg, Meter, Box, etc.). Default to "Pcs" if not specified
4. **totalAmount**: Total invoice amount (decimal). If not found, sum all product line totals

IMPORTANT:
- Extract unit prices, NOT line totals (e.g., if "5 items × ₹100 = ₹500", price should be 100.00, not 500.00)
- For product names, include relevant details but keep concise
- Ignore GST/tax line items as separate products
- If no products found, return empty array []
- All numeric fields must be numbers, not strings
- Return ONLY the JSON object, no additional text

Focus on accuracy over completeness. If data is unclear, make best estimate but prioritize correctness.
''';
  }

  /// Extract JSON from Gemini response (handles markdown code blocks)
  Map<String, dynamic> _extractJsonFromResponse(String response) {
    try {
      // Remove markdown code blocks if present
      String cleaned = response.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      // Parse JSON
      final jsonData = json.decode(cleaned) as Map<String, dynamic>;

      // Validate structure
      if (!jsonData.containsKey('products')) {
        jsonData['products'] = [];
      }
      if (!jsonData.containsKey('supplierName')) {
        jsonData['supplierName'] = 'Unknown Supplier';
      }
      if (!jsonData.containsKey('date')) {
        jsonData['date'] = '';
      }
      if (!jsonData.containsKey('totalAmount')) {
        jsonData['totalAmount'] = 0.0;
      }

      return jsonData;
    } catch (e) {
      print('Error parsing JSON from Gemini response: $e');
      print('Response was: $response');
      // Return empty structure if parsing fails
      return {
        'supplierName': 'Unknown Supplier',
        'date': '',
        'products': [],
        'totalAmount': 0.0,
      };
    }
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose resources (currently no-op, but useful for future cleanup)
  void dispose() {
    // Nothing to dispose currently
  }
}
