import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/localization_context.dart';
import '../theme/app_theme.dart';

/// Full-screen camera that pops with the first book ISBN it reads, or null
/// if the user backs out.
///
/// Only EAN-13 is decoded: that's the symbology printed on the back of books
/// and BD, and restricting to it keeps the detector from latching onto a
/// price sticker's EAN-8 or a QR code on the same cover.
class IsbnScannerScreen extends StatefulWidget {
  const IsbnScannerScreen({super.key});

  @override
  State<IsbnScannerScreen> createState() => _IsbnScannerScreenState();
}

class _IsbnScannerScreenState extends State<IsbnScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  // Bookland EAN: an ISBN-13 always starts 978 or 979. Any other EAN-13 is
  // a product barcode (a sticker, a non-book item) and would only produce a
  // confusing "not found".
  static final _isbn13 = RegExp(r'^97[89]\d{10}$');

  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && _isbn13.hasMatch(value)) {
        _done = true;
        HapticFeedback.selectionClick();
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: context.tr('scan.torch'),
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: _controller.toggleTorch,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(error: error),
          ),
          const _Viewfinder(),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48 + MediaQuery.viewPaddingOf(context).bottom,
            child: Text(
              context.tr('scan.hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// A landscape cut-out matching a barcode's shape, so it's obvious where to
/// aim; the rest of the preview is dimmed.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(child: CustomPaint(painter: _ViewfinderPainter()));
  }
}

class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width * 0.78;
    final height = width * 0.45;
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(center: size.center(Offset.zero), width: width, height: height),
      const Radius.circular(14),
    );
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) => false;
}

class _ScannerError extends StatelessWidget {
  final MobileScannerException error;

  const _ScannerError({required this.error});

  @override
  Widget build(BuildContext context) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => context.tr('scan.permissionDenied'),
      MobileScannerErrorCode.unsupported => context.tr('scan.unsupported'),
      _ => context.tr('scan.cameraError'),
    };
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}
