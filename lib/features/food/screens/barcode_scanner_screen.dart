import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../data/off_client.dart';
import 'food_detail_screen.dart';

/// Full-screen barcode scanner. Detects a code → looks it up on Open Food
/// Facts → pushes to FoodDetailScreen if found.
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  final MealTimeSlot slot;
  final DateTime date;
  const BarcodeScannerScreen({
    super.key,
    required this.slot,
    required this.date,
  });

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _cam = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _processing = false;
  String? _lastCode;

  late final AnimationController _laser;

  @override
  void initState() {
    super.initState();
    _laser = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laser.dispose();
    _cam.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code == _lastCode) return;

    setState(() {
      _processing = true;
      _lastCode = code;
    });

    final off = OffClient();
    final food = await off.byBarcode(code);

    if (!mounted) return;

    if (food == null) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No food found for barcode $code'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => setState(() => _lastCode = null),
          ),
        ),
      );
      return;
    }

    // Push to detail and close scanner.
    await _cam.stop();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(
          food: food,
          initialSlot: widget.slot,
          date: widget.date,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: _cam,
            onDetect: _onDetect,
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.x,
                          color: Colors.white, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    ValueListenableBuilder(
                      valueListenable: _cam,
                      builder: (_, state, _) => IconButton(
                        icon: Icon(
                          state.torchState == TorchState.on
                              ? LucideIcons.zapOff
                              : LucideIcons.zap,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => _cam.toggleTorch(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Dim outside the scan window with a 60% mask cut-out.
          IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.42),
              child: const SizedBox.expand(),
            ),
          ),

          // Scanning window — corner brackets + sweeping laser.
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                children: [
                  // Clear hole punched through the dim layer.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: -0.0),
                        backgroundBlendMode: BlendMode.dstOut,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  // 4 corner brackets.
                  ...const [
                    Alignment.topLeft,
                    Alignment.topRight,
                    Alignment.bottomLeft,
                    Alignment.bottomRight,
                  ].map((a) => Align(
                        alignment: a,
                        child: _CornerBracket(alignment: a, color: c.accent),
                      )),
                  // Animated laser line.
                  AnimatedBuilder(
                    animation: _laser,
                    builder: (context, _) {
                      final dy = _laser.value;
                      return Positioned(
                        left: 12,
                        right: 12,
                        top: 12 + (280 - 24 - 2) * dy,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(
                                color: c.accent.withValues(alpha: 0.55),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // BarcodeScanner is intentionally minimal — let the camera breathe.
          // Bottom hint
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_processing) ...[
                      const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      const SizedBox(height: 12),
                      Text('Looking up barcode…',
                          style: t.body.copyWith(color: Colors.white70)),
                    ] else ...[
                      Text('Point at a barcode',
                          style: t.h2.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        'Hold steady — it scans automatically',
                        style: t.body.copyWith(color: Colors.white60),
                      ),
                    ],
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

class _CornerBracket extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  const _CornerBracket({required this.alignment, required this.color});

  @override
  Widget build(BuildContext context) {
    const len = 26.0;
    const stroke = 3.0;
    final isTop = alignment == Alignment.topLeft ||
        alignment == Alignment.topRight;
    final isLeft = alignment == Alignment.topLeft ||
        alignment == Alignment.bottomLeft;
    return SizedBox(
      width: len,
      height: len,
      child: Stack(
        children: [
          // Horizontal stroke
          Positioned(
            top: isTop ? 0 : null,
            bottom: isTop ? null : 0,
            left: isLeft ? 0 : null,
            right: isLeft ? null : 0,
            child: Container(
              width: len,
              height: stroke,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(stroke / 2),
              ),
            ),
          ),
          // Vertical stroke
          Positioned(
            top: isTop ? 0 : null,
            bottom: isTop ? null : 0,
            left: isLeft ? 0 : null,
            right: isLeft ? null : 0,
            child: Container(
              width: stroke,
              height: len,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(stroke / 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
