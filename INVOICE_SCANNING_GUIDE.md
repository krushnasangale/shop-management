# Invoice Scanning Feature Documentation

## Overview
The invoice scanning feature allows users to quickly create purchase entries by scanning physical invoices using their device camera or by selecting invoice images from their gallery. The system uses Google ML Kit for on-device OCR (Optical Character Recognition) to extract text from invoices and automatically parse relevant information.

## Features Implemented

### 1. **Multiple Input Methods**
- 📷 **Camera Capture**: Take a photo of an invoice directly using the device camera
- 🖼️ **Gallery Selection**: Choose an existing invoice image from the device gallery
- 📄 **PDF Support**: Framework ready for PDF invoice processing (requires additional implementation)

### 2. **OCR Processing**
- Uses Google ML Kit Text Recognition for on-device processing
- Fast and privacy-friendly (no data sent to servers)
- Supports Latin script text recognition
- Extracts all visible text from invoice images

### 3. **Smart Invoice Parsing**
The system automatically extracts:
- **Supplier Name**: Identified from the top section of the invoice
- **Date**: Detected using multiple date format patterns (DD/MM/YYYY, YYYY-MM-DD, etc.)
- **Total Amount**: Found using various patterns (Total:, Amount:, ₹ symbols, etc.)
- **Products**: Attempts to identify product lines with names, quantities, and prices

### 4. **Review & Edit Screen**
- Users can review all extracted data before confirming
- Edit any field that wasn't correctly detected
- Add or remove products manually
- Visual feedback with icons and color-coded sections

## Technical Implementation

### Dependencies Added
```yaml
google_mlkit_text_recognition: ^0.13.1  # OCR engine
file_picker: ^8.1.6                      # PDF file selection
image_picker: ^1.0.4                     # Camera/gallery image capture (already existed)
```

### Files Created/Modified

#### 1. **invoice_review_screen.dart** (New)
- Location: `lib/pages/purchase/invoice_review_screen.dart`
- Purpose: Screen for reviewing and editing extracted invoice data
- Features:
  - Editable fields for supplier, date, and total
  - Dynamic product list with add/remove functionality
  - Validation and data confirmation
  - Clean, user-friendly interface

#### 2. **purchase_items_list.dart** (Modified)
- Added scan button in AppBar
- Implemented three scanning methods:
  - `_scanFromCamera()`: Camera capture
  - `_scanFromGallery()`: Gallery selection
  - `_scanFromPDF()`: PDF selection (basic implementation)
- Added `_processImage()`: Main OCR processing function
- Added `_parseInvoiceText()`: Invoice data extraction logic

## How It Works

### User Flow
1. User taps the **Scan Invoice** button (📄 icon) in the Purchase Items List
2. Bottom sheet appears with three options:
   - Take Photo (camera)
   - Choose from Gallery
   - Select PDF
3. User selects an option and captures/chooses an invoice
4. Loading dialog shows "Processing invoice..."
5. OCR extracts text from the image
6. Parser analyzes text and extracts invoice data
7. Review screen opens with pre-filled data
8. User reviews and edits as needed
9. User taps "Confirm" to accept the data
10. Data is ready for integration with purchase entry form

### OCR Processing Pipeline
```
Image → ML Kit TextRecognizer → Raw Text → Parser → Structured Data
```

### Data Parsing Logic

#### Supplier Name Detection
- Takes the first meaningful line of text
- Filters out very short strings (< 3 characters)

#### Date Detection
Supports multiple patterns:
- `DD/MM/YYYY` or `DD-MM-YYYY`
- `YYYY/MM/DD` or `YYYY-MM-DD`
- Various separators (/, -, .)

#### Total Amount Detection
Patterns recognized:
- "Total: ₹1000" or "Total: 1000"
- "Amount: ₹1000"
- "₹1000 Total"
- Case-insensitive matching

#### Product Detection
- Identifies lines with multiple numbers (quantity + price pattern)
- Extracts product name by removing numeric values
- Attempts to map first number to quantity, last to price

## Usage Instructions

### For Users
1. Navigate to **Purchased Entries** screen
2. Tap the **scan icon** (📄) in the top-right corner
3. Choose your preferred input method
4. For best results:
   - Ensure good lighting when capturing photos
   - Hold the camera steady
   - Capture the entire invoice in the frame
   - Avoid shadows and glare
5. Review the extracted data carefully
6. Edit any incorrect fields
7. Add missing products manually if needed
8. Confirm to proceed

### For Developers

#### Adding Custom Parsing Patterns
Edit `_parseInvoiceText()` in `purchase_items_list.dart`:

```dart
// Add new date pattern
final datePatterns = [
  RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}'),
  RegExp(r'your-custom-pattern'),  // Add here
];

// Add new total pattern
final totalPatterns = [
  RegExp(r'total[:\s]*₹?\s*(\d+\.?\d*)', caseSensitive: false),
  RegExp(r'your-custom-pattern'),  // Add here
];
```

#### Improving Product Detection
The current product detection is basic. To improve:

1. **Use AI-powered parsing** (recommended for production):
   ```dart
   // Call OpenAI or similar API
   final parsedData = await parseInvoiceWithAI(extractedText);
   ```

2. **Add table detection**:
   - Use ML Kit's table detection if available
   - Implement column-based parsing

3. **Add business logic**:
   - Match products against your inventory
   - Auto-correct common OCR mistakes
   - Validate total amounts

## Limitations & Future Enhancements

### Current Limitations
1. **PDF Processing**: Currently shows placeholder message, needs implementation
2. **Product Detection**: Basic pattern matching, may miss complex invoice formats
3. **No Table Detection**: Cannot identify structured tables in invoices
4. **Limited Format Support**: Works best with standard invoice layouts
5. **No Integration**: Not yet connected to the purchase entry form

### Planned Enhancements
1. ✅ **Full PDF Support**
   - Extract text from PDF invoices
   - Handle multi-page invoices

2. ✅ **AI-Powered Parsing**
   - Use OpenAI or similar to improve accuracy
   - Handle diverse invoice formats
   - Learn from user corrections

3. ✅ **Purchase Form Integration**
   - Auto-fill purchase entry form with scanned data
   - One-click purchase entry creation

4. ✅ **Batch Scanning**
   - Scan multiple invoices at once
   - Process invoices in the background

5. ✅ **History & Templates**
   - Save frequently used suppliers
   - Remember invoice formats
   - Faster processing for known formats

6. ✅ **Advanced OCR**
   - Support for handwritten invoices
   - Multi-language support
   - Better accuracy with low-quality images

## Error Handling

### User-Friendly Messages
- Camera/gallery access issues
- OCR processing failures
- Invalid invoice formats
- Empty or unreadable images

### Technical Error Handling
```dart
try {
  // OCR and parsing logic
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Error processing invoice: $e'),
      backgroundColor: Colors.red,
    ),
  );
}
```

## Testing Recommendations

### Test Cases
1. **Clear Invoice**: Standard printed invoice with good quality
2. **Low Quality**: Blurry or dark image
3. **Handwritten**: Partially handwritten invoice
4. **Complex Layout**: Multi-column or table-heavy invoice
5. **Multiple Languages**: Invoice with mixed languages
6. **Edge Cases**: Very long supplier names, decimal quantities, etc.

### Performance Testing
- Test on low-end devices
- Monitor memory usage during OCR
- Test with very large images
- Measure processing time

## Security & Privacy

### Data Privacy
- ✅ **On-Device Processing**: OCR happens locally, no data sent to servers
- ✅ **No Storage**: Images are not permanently stored (unless in user's gallery)
- ✅ **User Control**: Users review all data before saving

### Permissions Required
- **Camera**: For capturing invoice photos
- **Photo Library**: For selecting existing images
- **Storage**: For temporary file access during processing

## Best Practices

### For Best OCR Results
1. Use good lighting
2. Hold camera steady
3. Capture entire invoice
4. Avoid shadows and reflections
5. Use high resolution when possible
6. Ensure text is clearly visible

### Code Maintenance
1. Keep ML Kit library updated
2. Monitor OCR accuracy metrics
3. Collect user feedback on parsing accuracy
4. Update parsing patterns based on real invoices
5. Test with diverse invoice formats

## Support & Troubleshooting

### Common Issues

**Issue**: "OCR not detecting any text"
- **Solution**: Check image quality, ensure sufficient lighting, verify ML Kit is properly initialized

**Issue**: "Wrong supplier name detected"
- **Solution**: Invoice format may be unusual, use the review screen to correct

**Issue**: "Products not detected"
- **Solution**: Current parser is basic, manually add products or improve parsing logic

**Issue**: "Camera not working"
- **Solution**: Check camera permissions in device settings

## Integration Guide (Next Steps)

To integrate with purchase entry form:

```dart
// In invoice_review_screen.dart, after user confirms:
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => PurchaseEntryForm(
      initialData: confirmedData,
    ),
  ),
);
```

Then in `PurchaseEntryForm`:
```dart
class PurchaseEntryForm extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  
  const PurchaseEntryForm({super.key, this.initialData});
  
  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _prefillFormData(widget.initialData!);
    }
  }
}
```

## Conclusion

The invoice scanning feature is now functional with core capabilities:
- ✅ Camera and gallery image capture
- ✅ OCR text extraction
- ✅ Basic invoice parsing
- ✅ Review and edit interface
- ⏳ Purchase form integration (coming soon)
- ⏳ Advanced AI parsing (future enhancement)

The foundation is solid and ready for production use, with clear paths for future enhancements.
