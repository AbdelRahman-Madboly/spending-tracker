import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/design/app_icons.dart';
import '../core/design/tokens.dart';
import '../domain/barcode_scan.dart';

/// Everything the app needs to scan a barcode/QR code, behind one seam.
///
/// mobile_scanner talks to the platform camera through platform channels
/// that don't run under `flutter test`, so widget tests inject a fake
/// implementation of this interface instead of exercising the real one —
/// mirrors the pattern [PhotoCaptureService] uses for camera/gallery photo
/// capture.
abstract class BarcodeScanService {
  /// Opens the scanner UI (pushed on top of [context]) and returns the
  /// decoded barcode/QR value from the first successful scan, or null if
  /// the user backed out without scanning anything. The add sheet's scan.
  Future<String?> scan(BuildContext context);

  /// Opens the scanner in continuous mode (spec §6.3) and returns every
  /// product scanned, in order, a product scanned twice listed twice.
  /// Empty when nothing was scanned.
  Future<List<String>> scanMany(BuildContext context);
}

class MobileScannerBarcodeScanService implements BarcodeScanService {
  @override
  Future<String?> scan(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
  }

  @override
  Future<List<String>> scanMany(BuildContext context) async {
    final codes = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
          builder: (_) => const BarcodeScannerScreen(continuous: true)),
    );
    return codes ?? const [];
  }
}

/// The camera behind [BarcodeScannerScreen]: its preview, which reports
/// every code it reads, and its torch. The screen's own seam, so its
/// counting and buttons are tested without a camera.
abstract class ScannerCamera {
  Widget preview({required ValueChanged<String> onCode});

  /// Whether the torch is on, or null when the camera has none.
  ValueListenable<bool?> get torch;
  Future<void> toggleTorch();
  void dispose();
}

class MobileScannerCamera implements ScannerCamera {
  MobileScannerCamera() {
    _controller.addListener(_syncTorch);
  }

  final _controller = MobileScannerController();

  @override
  final ValueNotifier<bool?> torch = ValueNotifier<bool?>(null);

  void _syncTorch() {
    torch.value = switch (_controller.value.torchState) {
      TorchState.unavailable => null,
      TorchState.on => true,
      TorchState.off || TorchState.auto => false,
    };
  }

  @override
  Widget preview({required ValueChanged<String> onCode}) => MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue;
            if (value != null && value.isNotEmpty) onCode(value);
          }
        },
        // Never crash/hang on a denied camera permission or missing
        // camera hardware — show a plain Arabic message and let the user
        // back out with the app bar's back button instead.
        errorBuilder: (context, error) => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'تعذّر تشغيل الكاميرا. يرجى السماح بإذن الكاميرا من إعدادات التطبيق.',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );

  @override
  Future<void> toggleTorch() => _controller.toggleTorch();

  @override
  void dispose() {
    _controller.removeListener(_syncTorch);
    _controller.dispose();
    torch.dispose();
  }
}

/// Full-screen camera preview with a torch toggle (spec §6.3).
///
/// In single mode it pops itself with the first code it reads. In
/// [continuous] mode it counts products (see [BarcodeTally]) with a light
/// tick for each, and pops with all of them on تم or on back: a scan is a
/// capture, and backing out never throws one away.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({
    super.key,
    this.continuous = false,
    this.camera,
    this.clock = DateTime.now,
  });

  final bool continuous;

  /// Defaults to the device camera through mobile_scanner.
  final ScannerCamera? camera;
  final DateTime Function() clock;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late final ScannerCamera _camera = widget.camera ?? MobileScannerCamera();
  final _tally = BarcodeTally();

  // Guards single mode against onCode firing more than once (the camera
  // keeps reading frames until it is disposed): the first code is the only
  // one that should pop this screen.
  bool _handled = false;

  void _onCode(String code) {
    if (!widget.continuous) {
      if (_handled) return;
      _handled = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(code);
      return;
    }
    if (_tally.add(code, widget.clock())) {
      HapticFeedback.mediumImpact();
      setState(() {});
    }
  }

  void _finish() => Navigator.of(context).pop(_tally.codes);

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.continuous ? 'امسح المنتجات' : 'امسح الباركود'),
        actions: [
          ValueListenableBuilder<bool?>(
            valueListenable: _camera.torch,
            builder: (context, on, _) => on == null
                ? const SizedBox.shrink()
                : IconButton(
                    key: const Key('scan-torch'),
                    tooltip: on ? 'اطفي الفلاش' : 'شغّل الفلاش',
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: Icon(on ? AppIcons.torchOn : AppIcons.torchOff),
                    onPressed: _camera.toggleTorch,
                  ),
          ),
        ],
      ),
      body: _camera.preview(onCode: _onCode),
      bottomNavigationBar: widget.continuous ? _buildTally(context) : null,
    );
    if (!widget.continuous) return scaffold;
    return PopScope<List<String>>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: scaffold,
    );
  }

  Widget _buildTally(BuildContext context) {
    final count = _tally.count;
    final last = count == 0 ? null : _tally.codes.last;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.gutter, AppSpacing.ms, AppSpacing.gutter, AppSpacing.ms),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 0 ? 'وجّه الكاميرا على الباركود' : '$count منتج',
                      style: AppText.bodyStrong.copyWith(color: Colors.white),
                    ),
                    if (last != null)
                      Text(last,
                          textDirection: TextDirection.ltr,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption
                              .copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            if (count > 0)
              FilledButton.icon(
                key: const Key('scan-done'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(96, 48)),
                onPressed: _finish,
                icon: const Icon(AppIcons.check),
                label: const Text('تم'),
              ),
          ],
        ),
      ),
    );
  }
}
