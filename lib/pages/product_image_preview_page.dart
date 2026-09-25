import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/services/file_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class ProductImagePreviewPage extends StatefulWidget {
  const ProductImagePreviewPage({
    super.key,
    required this.imageUrl,
    required this.productName,
  });

  final String imageUrl;
  final String productName;

  @override
  State<ProductImagePreviewPage> createState() =>
      _ProductImagePreviewPageState();
}

class _ProductImagePreviewPageState extends State<ProductImagePreviewPage> {
  bool _busy = false;

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    final loc = AppLocalizations.of(context);
    try {
      final file = await _saveImage(temporary: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${loc?.download ?? 'Download'}: ${file.path}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc?.failedToDownload ?? 'Failed to download'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    final loc = AppLocalizations.of(context);
    try {
      final file = await _saveImage(temporary: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: widget.productName),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc?.failedToShare ?? 'Failed to share')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File> _saveImage({required bool temporary}) async {
    final response = await http.get(Uri.parse(widget.imageUrl));
    if (response.statusCode != 200) {
      throw Exception('Could not download image');
    }

    final fileName = FileService.generateTimestampedFileName(
      widget.productName.isEmpty ? 'product' : widget.productName,
      'jpg',
    );

    final Directory dir;
    if (temporary) {
      dir = await getTemporaryDirectory();
    } else {
      dir = await _downloadDirectory();
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File('${dir.path}${Platform.isWindows ? '\\' : '/'}$fileName');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  Future<Directory> _downloadDirectory() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      final downloads = Directory('/storage/emulated/0/Download/FlashBill');
      try {
        if (!await downloads.exists()) {
          await downloads.create(recursive: true);
        }
        return downloads;
      } catch (_) {
        return await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
      }
    }

    if (Platform.isWindows) {
      final documentsPath = Platform.environment['USERPROFILE'] ?? '';
      return Directory('$documentsPath\\Documents\\FlashBill');
    }

    return await getApplicationDocumentsDirectory();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      Center(child: Adaptive.progress(color: Colors.white)),
                  errorWidget: (context, url, error) => Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: scheme.onInverseSurface,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: EdgeInsets.fromLTRB(4, topInset + 4, 16, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.62),
                        Colors.black.withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _download,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                        icon: const Icon(Icons.download_outlined, size: 20),
                        label: Text(loc?.download ?? 'Download'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _share,
                        style: Adaptive.compactFilled,
                        icon: const Icon(Icons.share_outlined, size: 20),
                        label: Text(loc?.share ?? 'Share'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
