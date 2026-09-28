import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Everything `AddSheet` needs to scan a barcode/QR code, behind one seam.
///
/// mobile_scanner talks to the platform camera through platform channels
/// that don't run under `flutter test`, so widget tests inject a fake
/// implementation of this interface instead of exercising the real one —
/// mirrors the pattern [PhotoCaptureService] uses for camera/gallery photo
/// capture.
abstract class BarcodeScanService {
  /// Opens the scanner UI (pushed on top of [context]) and returns the
  /// decoded barcode/QR value from the first successful scan, or null if
  /// the user backed out without scanning anything.
  Future<String?> scan(BuildContext context);
}

class MobileScannerBarcodeScanService implements BarcodeScanService {
  @override
  Future<String?> scan(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
  }
}

/// Full-screen camera preview that pops itself with the first decoded
/// barcode/QR value it sees. Kept as a separate widget (rather than inline
/// in [MobileScannerBarcodeScanService]) purely for readability — the
/// service seam `AddSheet` actually depends on is [BarcodeScanService],
/// which is what tests fake.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();

  // Guards against onDetect firing more than once (mobile_scanner keeps
  // scanning frames until the controller is disposed) — the first decode
  // is the only one that should pop this screen.
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    if (capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('امسح الباركود'),
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        // Never crash/hang on a denied camera permission or missing
        // camera hardware — show a plain Arabic message and let the user
        // back out with the app bar's back button instead.
        errorBuilder: (context, error) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'تعذّر تشغيل الكاميرا. يرجى السماح بإذن الكاميرا من إعدادات التطبيق.',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
