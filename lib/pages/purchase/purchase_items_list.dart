import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/profile/my_profile.dart';
import 'package:flashbill/pages/purchase/add_purchase_entry.dart';
import 'package:flashbill/pages/purchase/purchase_entry_details.dart';
import 'package:flashbill/services/gemini_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/app_logger.dart';
import 'package:flashbill/utils/search_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PurchaseItemsList extends StatefulWidget {
  const PurchaseItemsList({super.key});

  @override
  State<PurchaseItemsList> createState() => _PurchaseItemsListState();
}

class _PurchaseItemsListState extends State<PurchaseItemsList> {
  late CollectionReference _boughtRef;
  List<Map<String, dynamic>> _boughtEntries = [];
  List<Map<String, dynamic>> _filteredEntries = [];
  List<Map<String, dynamic>> _displayedEntries = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _streamSubscription;
  late TextEditingController _searchController;
  bool _showSearchBar = false;
  final ScrollController _scrollController = ScrollController();
  int _displayedItemCount = 50;
  bool _isLoadingMore = false;
  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  String? _filterSupplier;

  bool get _hasActiveFilters =>
      _filterFromDate != null ||
      _filterToDate != null ||
      (_filterSupplier != null && _filterSupplier!.isNotEmpty);

  List<String> get _uniqueSuppliers {
    final names = _boughtEntries
        .map((e) => (e['supplierName'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterEntries);
    _scrollController.addListener(_onScroll);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _boughtRef = FirebaseFirestore.instance
          .collection('purchases')
          .doc(user.uid)
          .collection('items');
      _loadBoughtEntriesRealtime();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (_isLoadingMore || _displayedItemCount >= _filteredEntries.length) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _displayedItemCount = (_displayedItemCount + 50).clamp(
            0,
            _filteredEntries.length,
          );
          _displayedEntries = _filteredEntries
              .take(_displayedItemCount)
              .toList();
          _isLoadingMore = false;
        });
      }
    });
  }

  void _loadBoughtEntriesRealtime() {
    _streamSubscription = _boughtRef
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              final entries = snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).toList();

              setState(() {
                _boughtEntries = entries;
                _isLoading = false;
              });
              _filterEntries();
            }
          },
          onError: (error) {
            appLog('Error loading bought entries: $error');
            setState(() {
              _isLoading = false;
            });
          },
        );
  }

  DateTime? _parseEntryDate(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    try {
      final parsed = DateFormat('dd/MM/yyyy').parseStrict(value);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

  String _dateFilterLabel(AppLocalizations? loc) {
    final fmt = DateFormat('dd/MM/yyyy');
    if (_filterFromDate != null && _filterToDate != null) {
      return '${fmt.format(_filterFromDate!)} – ${fmt.format(_filterToDate!)}';
    }
    if (_filterFromDate != null) {
      return '${loc?.fromDate ?? 'From'} ${fmt.format(_filterFromDate!)}';
    }
    return '${loc?.upToDate ?? 'Up to'} ${fmt.format(_filterToDate!)}';
  }

  void _clearAllFilters() {
    setState(() {
      _filterFromDate = null;
      _filterToDate = null;
      _filterSupplier = null;
    });
    _filterEntries();
  }

  void _filterEntries() {
    final query = _searchController.text.trim();
    final results = _boughtEntries.where((entry) {
      if (query.isNotEmpty) {
        final supplierName = (entry['supplierName'] ?? '').toString();
        final totalAmount = (entry['totalAmount'] ?? '').toString();
        if (!SearchUtils.matchesSubsequence(supplierName, query) &&
            !SearchUtils.matchesSubsequence(totalAmount, query)) {
          return false;
        }
      }

      if (_filterSupplier != null && _filterSupplier!.isNotEmpty) {
        if ((entry['supplierName'] ?? '').toString() != _filterSupplier) {
          return false;
        }
      }

      if (_filterFromDate != null || _filterToDate != null) {
        final entryDate = _parseEntryDate(entry['date']);
        if (entryDate == null) return false;
        if (_filterFromDate != null && entryDate.isBefore(_filterFromDate!)) {
          return false;
        }
        if (_filterToDate != null && entryDate.isAfter(_filterToDate!)) {
          return false;
        }
      }

      return true;
    }).toList();

    setState(() {
      _filteredEntries = results;
      _displayedItemCount = 50;
      _displayedEntries = _filteredEntries.take(_displayedItemCount).toList();
    });
  }

  Future<void> _openFilterSheet() async {
    final loc = AppLocalizations.of(context);
    final result = await Adaptive.showSheet<_PurchaseFilterResult>(
      context: context,
      builder: (context) => _PurchaseFilterSheet(
        title: loc?.filterSort ?? 'Filter',
        cancelLabel: loc?.cancel ?? 'Cancel',
        applyLabel: loc?.apply ?? 'Apply',
        clearLabel: loc?.clear ?? 'Clear',
        fromLabel: loc?.fromDate ?? 'From',
        toLabel: loc?.upToDate ?? 'Up to',
        supplierLabel: loc?.supplier ?? 'Supplier',
        allSuppliersLabel: 'All Suppliers',
        selectDateLabel: loc?.selectDate ?? 'Select Date',
        initialFromDate: _filterFromDate,
        initialToDate: _filterToDate,
        initialSupplier: _filterSupplier,
        suppliers: _uniqueSuppliers,
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      _filterFromDate = result.fromDate;
      _filterToDate = result.toDate;
      _filterSupplier = result.supplier;
    });
    _filterEntries();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildRecentTab(AppLocalizations? loc) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (_showSearchBar)
          Adaptive.searchField(
            controller: _searchController,
            query: _searchController.text,
            hint:
                loc?.searchBySupplierOrAmount ?? 'Search by supplier or amount',
          ),
        if (_hasActiveFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_filterFromDate != null || _filterToDate != null)
                    InputChip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: scheme.primary,
                      ),
                      label: Text(_dateFilterLabel(loc)),
                      onDeleted: () {
                        setState(() {
                          _filterFromDate = null;
                          _filterToDate = null;
                        });
                        _filterEntries();
                      },
                    ),
                  if (_filterSupplier != null && _filterSupplier!.isNotEmpty)
                    InputChip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        Icons.local_shipping_outlined,
                        size: 16,
                        color: scheme.primary,
                      ),
                      label: Text(_filterSupplier!),
                      onDeleted: () {
                        setState(() => _filterSupplier = null);
                        _filterEntries();
                      },
                    ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: _clearAllFilters,
                    child: Text(loc?.clear ?? 'Clear'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _filteredEntries.isEmpty
              ? _EmptyState(
                  icon: Icons.search_off,
                  message:
                      loc?.noMatchingEntriesFound ??
                      'No matching entries found',
                )
              : ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                  children: [
                    Adaptive.fullWidthGroup(
                      context: context,
                      children: [
                        for (final entry in _displayedEntries)
                          _PurchaseEntryTile(
                            entry: entry,
                            onTap: () => AppNavigator.push(
                              context,
                              PurchaseEntryDetails(entry: entry),
                            ),
                          ),
                      ],
                    ),
                    if (_isLoadingMore)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(child: Adaptive.progress()),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.purchases ?? 'Purchases'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            style: Adaptive.compactIconButton.copyWith(
              iconSize: const WidgetStatePropertyAll(24),
            ),
            icon: Icon(
              _showSearchBar ? CupertinoIcons.xmark : CupertinoIcons.search,
              size: 24,
            ),
            tooltip: _showSearchBar
                ? (loc?.closeSearch ?? 'Close Search')
                : (loc?.search ?? 'Search'),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) _searchController.clear();
              });
            },
          ),
          IconButton(
            style: Adaptive.compactIconButton,
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              smallSize: 8,
              child: Icon(
                Icons.filter_list,
                size: 26,
                color: _hasActiveFilters
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
            tooltip: loc?.filterSort ?? 'Filter',
            onPressed: _boughtEntries.isEmpty ? null : _openFilterSheet,
          ),
          IconButton(
            style: Adaptive.compactIconButton.copyWith(
              iconSize: const WidgetStatePropertyAll(26),
            ),
            icon: const Icon(Icons.document_scanner_outlined, size: 26),
            tooltip: loc?.scanInvoice ?? 'Scan Invoice',
            onPressed: () => _showScanOptions(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 32),
            tooltip: loc?.addPurchase ?? 'Add Purchase',
            onPressed: () =>
                AppNavigator.push(context, const AddPurchaseEntry()),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.grey.withValues(alpha: 0.2),
            ),
            height: 40,
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.account_circle, size: 35),
              tooltip: loc?.myProfile ?? 'My Profile',
              onPressed: () => AppNavigator.push(context, const MyProfile()),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: _isLoading
          ? Center(child: Adaptive.progress())
          : _boughtEntries.isEmpty
          ? _EmptyState(
              icon: Icons.inventory_2_outlined,
              message: loc?.noPurchasedEntriesYet ?? 'No purchased entries yet',
            )
          : _buildRecentTab(loc),
    );
  }

  void _showScanOptions(BuildContext context) {
    final loc = AppLocalizations.of(context);
    Adaptive.showSheet<void>(
      context: context,
      builder: (sheetContext) {
        return _ScanInvoiceSheet(
          title: loc?.scanInvoice ?? 'Scan Invoice',
          subtitle: loc?.pdfScanLimitInfo ?? 'Choose how to scan this invoice',
          cancelLabel: loc?.cancel ?? 'Cancel',
          showCamera: Platform.isAndroid || Platform.isIOS,
          takePhotoLabel: loc?.takePhoto ?? 'Take Photo',
          takePhotoHint:
              loc?.captureInvoiceWithCamera ?? 'Capture invoice with camera',
          galleryLabel: loc?.chooseFromGallery ?? 'Choose from Gallery',
          galleryHint:
              loc?.selectInvoiceFromPhotos ?? 'Select invoice from photos',
          pdfLabel: loc?.selectPDF ?? 'Select PDF',
          pdfHint: loc?.choosePDFInvoice ?? 'Choose PDF invoice',
          onCamera: _scanFromCamera,
          onGallery: _scanFromGallery,
          onPdf: _scanFromPDF,
        );
      },
    );
  }

  Future<void> _scanFromCamera() async {
    final localizations = AppLocalizations.of(context);
    try {
      final ImagePicker picker = ImagePicker();
      appLog('Opening camera...');

      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        maxWidth: 3000, // Increase max resolution for better OCR
        maxHeight: 4000,
        preferredCameraDevice: CameraDevice.rear,
      );

      appLog('Photo captured: ${image?.path}');

      if (image != null && mounted) {
        await _processImage(image.path);
      } else {
        appLog('No photo captured or widget not mounted');
      }
    } catch (e, stackTrace) {
      appLog('Error in _scanFromCamera: $e');
      appLog('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations?.error ?? 'Error'}: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _scanFromGallery() async {
    final localizations = AppLocalizations.of(context);
    try {
      final ImagePicker picker = ImagePicker();
      appLog('Opening gallery picker...');

      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
        maxWidth: 3000, // Increase max resolution for better OCR
        maxHeight: 4000,
      );

      appLog('Image selected: ${image?.path}');

      if (image != null && mounted) {
        await _processImage(image.path);
      } else {
        appLog('No image selected or widget not mounted');
      }
    } catch (e, stackTrace) {
      appLog('Error in _scanFromGallery: $e');
      appLog('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations?.error ?? 'Error'}: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Helper method to show limited data detection dialog
  void _showLimitedDataDialog(
    int textLength,
    Map<String, dynamic> invoiceData,
  ) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                localizations?.limitedDataDetected ?? 'Limited Data Detected',
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations?.pdfNotGivingGoodResults ??
                    'This PDF is not giving us good results. Please try a different PDF.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                localizations?.tryDifferentPDF ?? 'For better results, try:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              _buildSuggestionRow(
                Icons.camera_alt,
                Colors.blue,
                localizations?.takeClearPhotoWithGoodLighting ??
                    'Take a clear photo with good lighting',
              ),
              SizedBox(height: 8),
              _buildSuggestionRow(
                Icons.picture_as_pdf,
                Colors.orange,
                localizations?.usePDFScanForBetterTableExtraction ??
                    'Use PDF scan for better table extraction',
              ),
              SizedBox(height: 8),
              _buildSuggestionRow(
                Icons.zoom_in,
                Colors.purple,
                localizations?.ensureTextIsLargeAndReadableInPhoto ??
                    'Ensure text is large and readable in photo',
              ),
              SizedBox(height: 8),
              _buildSuggestionRow(
                Icons.edit,
                Colors.green,
                localizations?.manuallyEnterPurchaseDetails ??
                    'Manually enter the purchase details',
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        localizations
                                ?.tipPDFScanningWorksBestForTableBasedInvoices ??
                            'Tip: PDF scanning works best for table-based invoices',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showScanOptions(context); // Open PDF selection popup again
            },
            child: Text(localizations?.retryScan ?? 'Retry Scan'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddPurchaseEntry(existingEntry: invoiceData),
                ),
              );
            },
            child: Text(localizations?.continueAnyway ?? 'Continue Anyway'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
      ],
    );
  }

  Future<void> _scanFromPDF() async {
    final loc = AppLocalizations.of(context);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null && mounted) {
          await _processPDF(file.path!);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  loc?.couldNotAccessPDFFile ?? 'Could not access PDF file',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${loc?.errorSelectingPDF ?? 'Error selecting PDF'}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processPDF(String pdfPath) async {
    final loc = AppLocalizations.of(context);
    bool isCancelled = false;
    String statusMessage = loc?.processingInvoice ?? 'Processing Invoice';
    int currentAttempt = 0;
    double scanProgress = 0.0;
    Timer? progressTimer;
    void Function(void Function())? dialogSetState;

    void startProgressTimer() {
      progressTimer?.cancel();
      progressTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
        if (scanProgress < 0.88) {
          dialogSetState?.call(() {
            final step = (0.88 - scanProgress) * 0.035;
            scanProgress = (scanProgress + step).clamp(0.0, 0.88);
          });
        }
      });
    }

    // Show loading dialog with stateful builder
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              dialogSetState = setDialogState; // Capture setState
              return PopScope(
                canPop: false,
                child: Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const CircularProgressIndicator(
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          statusMessage,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Powered by Gemini AI',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: scanProgress,
                            minHeight: 8,
                            backgroundColor: Colors.blue.withValues(
                              alpha: 0.15,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(scanProgress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        if (currentAttempt > 0) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              'Retry attempt $currentAttempt/5',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextButton.icon(
                          onPressed: () {
                            isCancelled = true;
                            Navigator.of(dialogContext).pop();
                          },
                          icon: const Icon(Icons.close),
                          label: Text(loc?.cancel ?? 'Cancel'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ).then((_) {
        // If dialog is dismissed, mark as cancelled
        isCancelled = true;
        progressTimer?.cancel();
      });
    }

    startProgressTimer();

    try {
      // Extract text from PDF
      final File file = File(pdfPath);
      final bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      String extractedText = '';
      final PdfTextExtractor extractor = PdfTextExtractor(document);

      // Limit to first 5 pages to support multi-page invoices
      // while avoiding token limits and rate limiting
      final int maxPages = document.pages.count > 5 ? 5 : document.pages.count;

      for (int i = 0; i < maxPages; i++) {
        final String pageText = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        extractedText += '$pageText\n';

        // Stop if we have enough text (15000 chars handles most multi-page invoices)
        if (extractedText.length > 15000) {
          extractedText = extractedText.substring(0, 15000);
          break;
        }
      }
      document.dispose();

      // Use Gemini to extract invoice data with retry callback
      final geminiService = GeminiService();
      final invoiceData = await geminiService.extractInvoiceData(
        pdfText: extractedText,
        onRetry: (attempt, delay) {
          // Update dialog state to show retry attempt
          currentAttempt = attempt;
          statusMessage = 'Retrying in $delay seconds...';
          scanProgress = 0.15;
          startProgressTimer();
          dialogSetState?.call(() {});
        },
        isCancelled: () => isCancelled,
      );

      progressTimer?.cancel();
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Check if meaningful data was extracted
        final products = invoiceData['products'] as List<dynamic>? ?? [];
        if (products.isEmpty && extractedText.length < 500) {
          _showLimitedDataDialog(extractedText.length, invoiceData);
        } else {
          // Navigate to purchase entry form
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddPurchaseEntry(existingEntry: invoiceData),
            ),
          );
        }
      }
    } catch (e) {
      progressTimer?.cancel();
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Don't show error if user cancelled
        if (e.toString().contains('Operation cancelled by user')) {
          return;
        }

        String errorMessage =
            '${loc?.errorProcessingPDF ?? 'Error processing PDF'}: $e';
        if (e.toString().contains('Too many requests')) {
          errorMessage =
              loc?.tooManyRequests ??
              'Too many requests. Please wait a moment and try again.';
        } else if (e.toString().contains('quota')) {
          errorMessage =
              loc?.quotaExceeded ??
              'Daily quota exceeded. Please try again tomorrow.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _processImage(String imagePath) async {
    final loc = AppLocalizations.of(context);
    bool isCancelled = false;
    String statusMessage = loc?.scanningInvoice ?? 'Scanning Invoice';
    int currentAttempt = 0;
    double scanProgress = 0.0;
    Timer? progressTimer;
    void Function(void Function())? dialogSetState;

    void startProgressTimer() {
      progressTimer?.cancel();
      progressTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
        if (scanProgress < 0.88) {
          dialogSetState?.call(() {
            final step = (0.88 - scanProgress) * 0.035;
            scanProgress = (scanProgress + step).clamp(0.0, 0.88);
          });
        }
      });
    }

    // Show loading dialog with stateful builder
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              dialogSetState = setDialogState; // Capture setState
              return PopScope(
                canPop: false,
                child: Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          statusMessage,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Powered by Gemini AI',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: scanProgress,
                            minHeight: 8,
                            backgroundColor: Colors.green.withValues(
                              alpha: 0.15,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(scanProgress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        if (currentAttempt > 0) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              'Retry attempt $currentAttempt/5',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextButton.icon(
                          onPressed: () {
                            isCancelled = true;
                            Navigator.of(dialogContext).pop();
                          },
                          icon: const Icon(Icons.close),
                          label: Text(loc?.cancel ?? 'Cancel'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ).then((_) {
        // If dialog is dismissed, mark as cancelled
        isCancelled = true;
        progressTimer?.cancel();
      });
    }

    startProgressTimer();

    try {
      // Use Gemini to extract invoice data directly from image
      final geminiService = GeminiService();
      final invoiceData = await geminiService.extractInvoiceData(
        imagePath: imagePath,
        onRetry: (attempt, delay) {
          // Update dialog state to show retry attempt
          currentAttempt = attempt;
          statusMessage = 'Retrying in $delay seconds...';
          scanProgress = 0.15;
          startProgressTimer();
          dialogSetState?.call(() {});
        },
        isCancelled: () => isCancelled,
      );

      progressTimer?.cancel();
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Check if meaningful data was extracted
        final products = invoiceData['products'] as List<dynamic>? ?? [];
        if (products.isEmpty) {
          _showLimitedDataDialog(0, invoiceData);
        } else {
          // Navigate to purchase entry form
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddPurchaseEntry(existingEntry: invoiceData),
            ),
          );
        }
      }
    } catch (e) {
      progressTimer?.cancel();
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Don't show error if user cancelled
        if (e.toString().contains('Operation cancelled by user')) {
          return;
        }

        String errorMessage =
            '${loc?.errorProcessingInvoice ?? 'Error processing invoice'}: $e';
        if (e.toString().contains('Too many requests')) {
          errorMessage =
              loc?.tooManyRequests ??
              'Too many requests. Please wait a moment and try again.';
        } else if (e.toString().contains('quota')) {
          errorMessage =
              loc?.quotaExceeded ??
              'Daily quota exceeded. Please try again tomorrow.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

class _PurchaseEntryTile extends StatelessWidget {
  const _PurchaseEntryTile({required this.entry, required this.onTap});

  final Map<String, dynamic> entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final supplier = (entry['supplierName'] ?? 'Unknown').toString();
    final date = (entry['date'] ?? 'N/A').toString();
    final products = entry['totalProducts'] ?? 0;
    final units = entry['totalUnits'] ?? 0;
    final amount = (entry['totalAmount'] ?? 0) as num;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
      minVerticalPadding: 4,
      onTap: onTap,
      leading: _squareIcon(Icons.inventory_2_outlined, scheme),
      title: Text(
        supplier,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      subtitle: Text(
        [
          date,
          '$products ${loc?.products ?? 'Products'}',
          '$units ${loc?.totalQuantity ?? 'Qty'}',
        ].join('  ·  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '₹${_formatAmount(amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 24,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _ScanInvoiceSheet extends StatelessWidget {
  const _ScanInvoiceSheet({
    required this.title,
    required this.subtitle,
    required this.cancelLabel,
    required this.showCamera,
    required this.takePhotoLabel,
    required this.takePhotoHint,
    required this.galleryLabel,
    required this.galleryHint,
    required this.pdfLabel,
    required this.pdfHint,
    required this.onCamera,
    required this.onGallery,
    required this.onPdf,
  });

  final String title;
  final String subtitle;
  final String cancelLabel;
  final bool showCamera;
  final String takePhotoLabel;
  final String takePhotoHint;
  final String galleryLabel;
  final String galleryHint;
  final String pdfLabel;
  final String pdfHint;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onPdf;

  void _select(BuildContext context, VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final options =
        <({IconData icon, String title, String hint, VoidCallback onTap})>[
          if (showCamera)
            (
              icon: Icons.camera_alt_outlined,
              title: takePhotoLabel,
              hint: takePhotoHint,
              onTap: onCamera,
            ),
          (
            icon: Icons.photo_library_outlined,
            title: galleryLabel,
            hint: galleryHint,
            onTap: onGallery,
          ),
          (
            icon: Icons.picture_as_pdf_outlined,
            title: pdfLabel,
            hint: pdfHint,
            onTap: onPdf,
          ),
        ];

    if (Adaptive.isCupertino) {
      return CupertinoActionSheet(
        title: Text(title),
        message: Text(subtitle),
        actions: [
          for (final option in options)
            CupertinoActionSheetAction(
              onPressed: () => _select(context, option.onTap),
              child: Text(option.title),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(cancelLabel),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (var i = 0; i < options.length; i++) ...[
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                        leading: _squareIcon(options[i].icon, scheme),
                        title: Text(
                          options[i].title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        subtitle: Text(options[i].hint),
                        trailing: Icon(
                          CupertinoIcons.chevron_forward,
                          size: 24,
                          color: scheme.onSurfaceVariant,
                        ),
                        onTap: () => _select(context, options[i].onTap),
                      ),
                      if (i != options.length - 1)
                        const Divider(height: 1, indent: 64),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: Adaptive.compactOutlined.copyWith(
                  minimumSize: const WidgetStatePropertyAll(
                    Size.fromHeight(46),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(cancelLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _squareIcon(icon, scheme),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _squareIcon(IconData icon, ColorScheme scheme) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: ColoredBox(
      color: scheme.primaryContainer,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
      ),
    ),
  );
}

String _formatAmount(num amount) {
  if (amount == amount.roundToDouble()) return amount.toInt().toString();
  return amount.toStringAsFixed(2);
}

class _PurchaseFilterResult {
  const _PurchaseFilterResult({this.fromDate, this.toDate, this.supplier});

  final DateTime? fromDate;
  final DateTime? toDate;
  final String? supplier;
}

class _PurchaseFilterSheet extends StatefulWidget {
  const _PurchaseFilterSheet({
    required this.title,
    required this.cancelLabel,
    required this.applyLabel,
    required this.clearLabel,
    required this.fromLabel,
    required this.toLabel,
    required this.supplierLabel,
    required this.allSuppliersLabel,
    required this.selectDateLabel,
    required this.initialFromDate,
    required this.initialToDate,
    required this.initialSupplier,
    required this.suppliers,
  });

  final String title;
  final String cancelLabel;
  final String applyLabel;
  final String clearLabel;
  final String fromLabel;
  final String toLabel;
  final String supplierLabel;
  final String allSuppliersLabel;
  final String selectDateLabel;
  final DateTime? initialFromDate;
  final DateTime? initialToDate;
  final String? initialSupplier;
  final List<String> suppliers;

  @override
  State<_PurchaseFilterSheet> createState() => _PurchaseFilterSheetState();
}

class _PurchaseFilterSheetState extends State<_PurchaseFilterSheet> {
  late DateTime? _fromDate = widget.initialFromDate;
  late DateTime? _toDate = widget.initialToDate;
  late String? _supplier = widget.initialSupplier;

  String _formatDate(DateTime? date) {
    if (date == null) return widget.selectDateLabel;
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = (isFrom ? _fromDate : _toDate) ?? now;
    final firstDate = DateTime(2020);
    final lastDate = DateTime(now.year + 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate)
          ? firstDate
          : (initial.isAfter(lastDate) ? lastDate : initial),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null || !mounted) return;

    final normalized = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      if (isFrom) {
        _fromDate = normalized;
        if (_toDate != null && _toDate!.isBefore(normalized)) {
          _toDate = normalized;
        }
      } else {
        _toDate = normalized;
        if (_fromDate != null && _fromDate!.isAfter(normalized)) {
          _fromDate = normalized;
        }
      }
    });
  }

  Future<void> _pickSupplier() async {
    final selected = await Adaptive.showSheet<String>(
      context: context,
      builder: (context) => _PurchaseSupplierFilterSheet(
        title: widget.supplierLabel,
        cancelLabel: widget.cancelLabel,
        allLabel: widget.allSuppliersLabel,
        suppliers: widget.suppliers,
        selected: _supplier,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _supplier = selected.isEmpty ? null : selected;
    });
  }

  void _clear() {
    Navigator.pop(context, const _PurchaseFilterResult());
  }

  void _apply() {
    Navigator.pop(
      context,
      _PurchaseFilterResult(
        fromDate: _fromDate,
        toDate: _toDate,
        supplier: _supplier,
      ),
    );
  }

  Widget _selectorField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: Adaptive.compactField(label: label, icon: icon).copyWith(
          suffixIcon: trailing,
          suffixIconConstraints: trailing == null
              ? null
              : Adaptive.compactPrefixConstraints,
        ),
        child: Text(
          value,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final supplierValue = (_supplier == null || _supplier!.isEmpty)
        ? widget.allSuppliersLabel
        : _supplier!;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Filter by date or supplier',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _selectorField(
              label: widget.fromLabel,
              value: _formatDate(_fromDate),
              icon: Icons.calendar_today_outlined,
              onTap: () => _pickDate(isFrom: true),
              trailing: _fromDate == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _fromDate = null),
                    ),
            ),
            const SizedBox(height: 12),
            _selectorField(
              label: widget.toLabel,
              value: _formatDate(_toDate),
              icon: Icons.event_outlined,
              onTap: () => _pickDate(isFrom: false),
              trailing: _toDate == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _toDate = null),
                    ),
            ),
            const SizedBox(height: 12),
            _selectorField(
              label: widget.supplierLabel,
              value: supplierValue,
              icon: Icons.local_shipping_outlined,
              onTap: _pickSupplier,
              trailing: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: Adaptive.compactIconSize,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: Adaptive.compactOutlined,
                    onPressed: _clear,
                    child: Text(widget.clearLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: Adaptive.compactFilled.copyWith(
                      minimumSize: const WidgetStatePropertyAll(
                        Size.fromHeight(42),
                      ),
                    ),
                    onPressed: _apply,
                    child: Text(widget.applyLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(widget.cancelLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseSupplierFilterSheet extends StatelessWidget {
  const _PurchaseSupplierFilterSheet({
    required this.title,
    required this.cancelLabel,
    required this.allLabel,
    required this.suppliers,
    required this.selected,
  });

  final String title;
  final String cancelLabel;
  final String allLabel;
  final List<String> suppliers;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = <String?>[null, ...suppliers];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (context, index) {
                    final supplier = options[index];
                    final label = supplier ?? allLabel;
                    final isSelected = supplier == null
                        ? selected == null || selected!.isEmpty
                        : selected == supplier;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      title: Text(
                        label,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, supplier ?? ''),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: Adaptive.compactOutlined,
                onPressed: () => Navigator.pop(context),
                child: Text(cancelLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
