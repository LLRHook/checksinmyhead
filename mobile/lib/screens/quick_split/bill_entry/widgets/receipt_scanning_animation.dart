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

import 'dart:io';
import 'dart:ui' as ui;

import 'package:checks_frontend/services/mlkit_ocr_service.dart';
import 'package:flutter/material.dart';

/// Scanner animation with progressive OCR box reveal.
///
/// Scan line sweeps once from top to bottom. As it passes each detected
/// text region, a bounding box fades in. After the scan completes, the
/// status bar switches to a loading state while the API processes.
class ReceiptScanningAnimation extends StatefulWidget {
  final String imagePath;
  final bool isComplete;
  final VoidCallback? onDismissed;
  final List<OcrTextLine>? ocrLines;
  final Size? imageSize;

  const ReceiptScanningAnimation({
    super.key,
    required this.imagePath,
    this.isComplete = false,
    this.onDismissed,
    this.ocrLines,
    this.imageSize,
  });

  @override
  State<ReceiptScanningAnimation> createState() =>
      _ReceiptScanningAnimationState();
}

class _ReceiptScanningAnimationState extends State<ReceiptScanningAnimation>
    with TickerProviderStateMixin {
  // Single scan pass (4s, does NOT repeat)
  late AnimationController _scanController;
  late AnimationController _bracketController;
  late AnimationController _bracketPulseController;
  late AnimationController _entryController;
  late AnimationController _dismissController;

  late FileImage _fileImage;
  bool _dismissed = false;
  bool _scanComplete = false;

  final Set<int> _revealedLines = {};

  @override
  void initState() {
    super.initState();
    _fileImage = FileImage(File(widget.imagePath));

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _scanController.addListener(_checkScanLineReveal);
    _scanController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_scanComplete) {
        setState(() => _scanComplete = true);
      }
    });

    _bracketController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _bracketPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _dismissController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_dismissed) {
        _dismissed = true;
        widget.onDismissed?.call();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryController.forward();
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _bracketController.forward();
      });
    });
  }

  void _checkScanLineReveal() {
    final lines = widget.ocrLines;
    final imgSize = widget.imageSize;
    if (lines == null || imgSize == null || imgSize.height == 0) return;

    final scanY = _scanController.value;

    bool changed = false;
    for (int i = 0; i < lines.length; i++) {
      if (_revealedLines.contains(i)) continue;
      final lineCenter =
          (lines[i].boundingBox.center.dy / imgSize.height).clamp(0.0, 1.0);
      if (scanY >= lineCenter) {
        _revealedLines.add(i);
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  @override
  void didUpdateWidget(ReceiptScanningAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isComplete && !oldWidget.isComplete && !_dismissed) {
      _dismissController.forward();
    }
    // OCR results just arrived — start the scan pass
    if (widget.ocrLines != null && oldWidget.ocrLines == null) {
      _revealedLines.clear();
      _scanController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _scanController.removeListener(_checkScanLineReveal);
    _scanController.dispose();
    _bracketController.dispose();
    _bracketPulseController.dispose();
    _entryController.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final safePadding = MediaQuery.of(context).padding;

    return AnimatedBuilder(
      animation: Listenable.merge([_entryController, _dismissController]),
      builder: (context, child) {
        final entry = CurvedAnimation(
          parent: _entryController,
          curve: Curves.easeOut,
        ).value;
        final dismiss = CurvedAnimation(
          parent: _dismissController,
          curve: Curves.easeIn,
        ).value;
        final opacity = entry * (1.0 - dismiss);

        if (opacity <= 0) return const SizedBox.shrink();

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Scaffold(
            backgroundColor: const Color(0xFF0E0E0E),
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _buildReceiptWithOverlays(colorScheme),
                    ),
                  ),
                  _buildStatusBar(colorScheme, safePadding.bottom),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptWithOverlays(ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageRect = _computeImageRect(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        return Stack(
          children: [
            // Receipt image
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: _fileImage,
                  fit: BoxFit.contain,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.receipt_long,
                        size: 48, color: Colors.white24),
                  ),
                ),
              ),
            ),
            // Progressive OCR boxes
            if (widget.ocrLines != null && widget.imageSize != null)
              ..._buildOcrBoxes(colorScheme, imageRect),
            // Scan line (only during scan, constrained to image)
            if (!_scanComplete)
              AnimatedBuilder(
                animation: _scanController,
                builder: (context, _) {
                  return Positioned(
                    left: imageRect.left,
                    top: imageRect.top,
                    width: imageRect.width,
                    height: imageRect.height,
                    child: CustomPaint(
                      painter: _ScanLinePainter(
                        position: _scanController.value,
                        color: colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
            // Corner brackets (around image)
            AnimatedBuilder(
              animation: Listenable.merge(
                  [_bracketController, _bracketPulseController]),
              builder: (context, _) {
                final bracketEntry = CurvedAnimation(
                  parent: _bracketController,
                  curve: Curves.easeOutCubic,
                ).value;
                final pulse = CurvedAnimation(
                  parent: _bracketPulseController,
                  curve: Curves.easeInOut,
                ).value;
                final bracketOpacity =
                    (bracketEntry * (0.6 + pulse * 0.4)).clamp(0.0, 1.0);

                return Positioned(
                  left: imageRect.left,
                  top: imageRect.top,
                  width: imageRect.width,
                  height: imageRect.height,
                  child: CustomPaint(
                    painter: _CornerBracketPainter(
                      color: colorScheme.primary
                          .withValues(alpha: bracketOpacity),
                      inset: (1.0 - bracketEntry) * 12,
                      bracketLength: 28,
                      strokeWidth: 2.0,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Rect _computeImageRect(double containerW, double containerH) {
    final imgSize = widget.imageSize;
    if (imgSize == null || imgSize.width == 0 || imgSize.height == 0) {
      return Rect.fromLTWH(0, 0, containerW, containerH);
    }

    final imageAspect = imgSize.width / imgSize.height;
    final containerAspect = containerW / containerH;

    double renderW, renderH;
    if (imageAspect > containerAspect) {
      renderW = containerW;
      renderH = containerW / imageAspect;
    } else {
      renderH = containerH;
      renderW = containerH * imageAspect;
    }

    return Rect.fromLTWH(
      (containerW - renderW) / 2,
      (containerH - renderH) / 2,
      renderW,
      renderH,
    );
  }

  List<Widget> _buildOcrBoxes(ColorScheme colorScheme, Rect imageRect) {
    final lines = widget.ocrLines!;
    final imgSize = widget.imageSize!;

    return List.generate(lines.length, (i) {
      if (!_revealedLines.contains(i)) return const SizedBox.shrink();

      final bbox = lines[i].boundingBox;
      final left =
          imageRect.left + (bbox.left / imgSize.width) * imageRect.width;
      final top =
          imageRect.top + (bbox.top / imgSize.height) * imageRect.height;
      final width = (bbox.width / imgSize.width) * imageRect.width;
      final height = (bbox.height / imgSize.height) * imageRect.height;

      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (context, value, _) {
            return Opacity(
              opacity: value,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(3),
                  color: colorScheme.primary.withValues(alpha: 0.08),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildStatusBar(ColorScheme colorScheme, double bottomPadding) {
    String statusText;
    if (_scanComplete) {
      statusText = 'Processing items…';
    } else if (widget.ocrLines != null) {
      statusText =
          'Found ${_revealedLines.length} of ${widget.ocrLines!.length} text regions…';
    } else {
      statusText = 'Analyzing receipt…';
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 14, 24, 14 + bottomPadding),
          color: const Color(0xFF0E0E0E).withValues(alpha: 0.7),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                statusText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double position;
  final Color color;

  _ScanLinePainter({required this.position, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * position;

    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0.7),
          color.withValues(alpha: 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, y - 0.5, size.width, 1));

    canvas.drawRect(Rect.fromLTWH(0, y - 0.5, size.width, 1.0), linePaint);

    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 30, size.width, 30));

    canvas.drawRect(Rect.fromLTWH(0, y - 30, size.width, 30), glowPaint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => position != old.position;
}

class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final double inset;
  final double bracketLength;
  final double strokeWidth;

  _CornerBracketPainter({
    required this.color,
    required this.inset,
    required this.bracketLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final l = bracketLength;
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;

    canvas.drawLine(Offset(left, top + l), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + l, top), paint);

    canvas.drawLine(Offset(right - l, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + l), paint);

    canvas.drawLine(Offset(left, bottom - l), Offset(left, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left + l, bottom), paint);

    canvas.drawLine(Offset(right - l, bottom), Offset(right, bottom), paint);
    canvas.drawLine(Offset(right, bottom - l), Offset(right, bottom), paint);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter old) =>
      color != old.color || inset != old.inset;
}
