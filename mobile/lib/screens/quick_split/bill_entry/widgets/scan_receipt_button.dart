// Billington: Privacy-first receipt splitting
//     Copyright (C) 2025  Kruski Ko.
//     Email us: checkmateapp@duck.com

//     This program is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.

//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.

//     You should have received a copy of the GNU General Public License
//     along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';
import 'dart:io';

import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/widgets/receipt_compare_screen.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/widgets/receipt_scanning_animation.dart';
import 'package:checks_frontend/services/mlkit_ocr_service.dart';
import 'package:checks_frontend/services/receipt_api_service.dart';
import 'package:checks_frontend/services/receipt_matcher.dart';
import 'package:checks_frontend/services/receipt_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// A button that triggers receipt scanning via camera or gallery,
/// uploads the image to the backend for AI-powered parsing, and lets
/// the user review parsed results before applying to BillData.
class ScanReceiptButton extends StatefulWidget {
  const ScanReceiptButton({super.key});

  @override
  State<ScanReceiptButton> createState() => _ScanReceiptButtonState();
}

class _ScanReceiptButtonState extends State<ScanReceiptButton> {
  bool _isProcessing = false;
  final _receiptApi = ReceiptApiService();

  // TODO: Remove after testing — dev shortcut to bypass photo picker
  Future<void> _devTestWithReceipt() async {
    final testPath = '${Directory.systemTemp.path}/test_receipt.jpg';
    if (!File(testPath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No test receipt found in tmp/')),
      );
      return;
    }
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    await _launchScanFlow(testPath);
  }

  Future<void> _scanReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ImageSourceSheet(),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1500,
      imageQuality: 75,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (pickedFile == null || !mounted) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    await _launchScanFlow(pickedFile.path);
  }

  Future<void> _launchScanFlow(String imagePath) async {

    // Push the full-screen scan flow (scanning animation → compare view)
    final confirmed = await Navigator.of(context).push<ParsedReceipt>(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ReceiptScanFlow(
            imagePath: imagePath,
            receiptApi: _receiptApi,
          );
        },
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (confirmed != null) {
      final billData = Provider.of<BillData>(context, listen: false);
      billData.populateFromScan(confirmed);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    final bgColor = brightness == Brightness.dark
        ? colorScheme.surface
        : Colors.white;
    final shadowColor = brightness == Brightness.dark
        ? Colors.black.withValues(alpha: .2)
        : Colors.black.withValues(alpha: .05);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _isProcessing ? null : _scanReceipt,
          // Dev: long-press to test with /tmp/test_receipt.jpg (bypass photo picker)
          onLongPress: kDebugMode && !_isProcessing ? _devTestWithReceipt : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isProcessing
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colorScheme.primary,
                          ),
                        )
                      : Icon(
                          Icons.document_scanner_outlined,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isProcessing ? 'Scanning Receipt...' : 'Scan Receipt',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Auto-fill from a photo',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Orchestrates the scanning animation → compare screen flow.
///
/// Shows [ReceiptScanningAnimation] while the API processes, then
/// pushes [ReceiptCompareScreen] when results arrive. Returns the
/// confirmed [ParsedReceipt] or null via Navigator.pop.
class _ReceiptScanFlow extends StatefulWidget {
  final String imagePath;
  final ReceiptApiService receiptApi;

  const _ReceiptScanFlow({
    required this.imagePath,
    required this.receiptApi,
  });

  @override
  State<_ReceiptScanFlow> createState() => _ReceiptScanFlowState();
}

class _ReceiptScanFlowState extends State<_ReceiptScanFlow> {
  bool _isScanning = true;
  String? _errorMessage;
  final _dismissCompleter = Completer<void>();
  final _mlkitOcr = MlkitOcrService();

  // OCR results fed to the animation for progressive box reveal
  OcrResult? _ocrResult;

  @override
  void dispose() {
    _mlkitOcr.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startParsing();
  }

  Future<void> _startParsing() async {
    // Timer starts after OCR completes (when the scan animation begins).
    // Declared here so catch blocks can access it.
    DateTime? animationStart;
    Future<void> ensureMinDuration() async {
      if (animationStart == null) return;
      final elapsed = DateTime.now().difference(animationStart!);
      final remaining = const Duration(milliseconds: 4500) - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
    }

    try {
      // STEP 1: Run ML Kit OCR on-device (fast, ~200ms)
      final ocrResult = await _mlkitOcr.recognizeText(widget.imagePath);

      // Feed OCR results to animation — scan line starts now
      if (mounted) {
        setState(() => _ocrResult = ocrResult);
      }
      animationStart = DateTime.now();

      ParsedReceipt parsed;
      Size? imageSize = ocrResult.imageSize;

      if (ocrResult.fullText.trim().length < 20) {
        parsed = await widget.receiptApi.parseReceipt(widget.imagePath);
      } else {
        // STEP 2: Send text to backend (runs while scan animation plays)
        final (textParsed, rawOcrNames) =
            await widget.receiptApi.parseReceiptText(ocrResult.fullText);

        // STEP 3: Fuzzy-match to recover bounding boxes
        final matchedItems = ReceiptMatcher.matchBoundingBoxes(
          parsedItems: textParsed.items,
          ocrResult: ocrResult,
          rawOcrNames: rawOcrNames,
        );

        parsed = ParsedReceipt(
          vendor: textParsed.vendor,
          items: matchedItems,
          subtotal: textParsed.subtotal,
          tax: textParsed.tax,
          tip: textParsed.tip,
          total: textParsed.total,
        );
      }

      if (!mounted) return;

      await ensureMinDuration();
      if (!mounted) return;

      if (parsed.items.isEmpty &&
          parsed.subtotal == null &&
          parsed.tax == null) {
        setState(() {
          _errorMessage = 'Could not detect receipt items. Try a clearer photo.';
          _isScanning = false;
        });
        return;
      }

      // Trigger dismiss animation and wait for it to complete
      setState(() => _isScanning = false);
      await _dismissCompleter.future;
      if (!mounted) return;

      final confirmed = await Navigator.of(context).push<ParsedReceipt>(
        MaterialPageRoute(
          builder: (context) => ReceiptCompareScreen(
            receipt: parsed,
            imagePath: widget.imagePath,
            imageSize: imageSize,
          ),
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(confirmed);
      }
    } on ReceiptParseException catch (e) {
      await ensureMinDuration();
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isScanning = false;
        });
      }
    } catch (e) {
      await ensureMinDuration();
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to process receipt. Please try again.';
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorState(context);
    }

    return ReceiptScanningAnimation(
      imagePath: widget.imagePath,
      isComplete: !_isScanning,
      ocrLines: _ocrResult?.lines,
      imageSize: _ocrResult?.imageSize,
      onDismissed: () {
        if (!_dismissCompleter.isCompleted) {
          _dismissCompleter.complete();
        }
      },
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    color: colorScheme.error, size: 56),
                const SizedBox(height: 20),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for choosing between camera and gallery.
class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? colorScheme.surface
            : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Scan Receipt',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt, color: colorScheme.primary),
              ),
              title: const Text('Camera'),
              subtitle: const Text('Take a photo of the receipt'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_library, color: colorScheme.primary),
              ),
              title: const Text('Gallery'),
              subtitle: const Text('Choose from photo library'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
