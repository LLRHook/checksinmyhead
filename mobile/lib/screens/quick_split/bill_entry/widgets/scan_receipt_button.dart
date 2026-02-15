// Billington: Privacy-first receipt spliting
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

import 'dart:io';

import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/widgets/receipt_review_sheet.dart';
import 'package:checks_frontend/services/image_preprocessor.dart';
import 'package:checks_frontend/services/receipt_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// A button that triggers receipt scanning via camera or gallery,
/// processes the image with ML Kit on-device OCR, and lets the user
/// review parsed results before applying to BillData.
class ScanReceiptButton extends StatefulWidget {
  const ScanReceiptButton({super.key});

  @override
  State<ScanReceiptButton> createState() => _ScanReceiptButtonState();
}

class _ScanReceiptButtonState extends State<ScanReceiptButton> {
  bool _isProcessing = false;

  Future<void> _scanReceipt() async {
    // Pick image source
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ImageSourceSheet(),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 3000,
      imageQuality: 95,
    );

    if (pickedFile == null || !mounted) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    String? preprocessedPath;
    try {
      // Preprocess image for better OCR accuracy
      preprocessedPath = await ImagePreprocessor.preprocess(pickedFile.path);

      // Run ML Kit text recognition on preprocessed image (fall back to original)
      final ocrPath = preprocessedPath ?? pickedFile.path;
      final inputImage = InputImage.fromFile(File(ocrPath));
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      var recognizedText = await textRecognizer.processImage(inputImage);

      // If preprocessed image yielded nothing, retry with original
      if (preprocessedPath != null && recognizedText.blocks.isEmpty) {
        final originalImage = InputImage.fromFile(File(pickedFile.path));
        recognizedText = await textRecognizer.processImage(originalImage);
      }

      await textRecognizer.close();

      if (!mounted) return;

      // Parse the recognized text
      final parsed = ReceiptParser.parse(recognizedText);

      setState(() => _isProcessing = false);

      if (parsed.items.isEmpty &&
          parsed.subtotal == null &&
          parsed.tax == null) {
        _showError('Could not detect receipt items. Try a clearer photo.');
        return;
      }

      // Show review sheet
      if (!mounted) return;
      final confirmed = await showModalBottomSheet<ParsedReceipt>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ReceiptReviewSheet(receipt: parsed),
      );

      if (confirmed != null && mounted) {
        final billData = Provider.of<BillData>(context, listen: false);
        billData.populateFromScan(confirmed);
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Failed to process receipt. Please try again.');
      }
    } finally {
      // Clean up preprocessed temp file
      if (preprocessedPath != null) {
        try {
          final tempFile = File(preprocessedPath);
          if (await tempFile.exists()) {
            await tempFile.parent.delete(recursive: true);
          }
        } catch (_) {}
      }
    }
  }

  void _showError(String message) {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        width: MediaQuery.of(context).size.width * 0.9,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
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
