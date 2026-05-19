import 'package:flutter/material.dart';
import 'package:hermes_mobile/features/preview/models/device_preset.dart';

/// Renders a device bezel frame around a [child] widget (typically a WebView).
///
/// For phone/tablet presets a rounded-corner bezel with a notch cutout and
/// camera dot.  For desktop a thin monitor bezel with a small stand.
/// The entire frame is scaled by [preset.scale] so it fits the available area.
class DeviceFrame extends StatelessWidget {
  /// The widget (WebView) to display inside the device frame.
  final Widget child;

  /// The device preset that controls frame style, dimensions, and scale.
  final DevicePreset preset;

  /// Optional fixed height override (if not provided, uses [preset.height]).
  final double? height;

  /// Optional fixed width override (if not provided, uses [preset.width]).
  final double? width;

  const DeviceFrame({
    super.key,
    required this.child,
    required this.preset,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final double frameWidth = width ?? preset.width;
    final double frameHeight = height ?? preset.height;

    return Transform.scale(
      scale: preset.scale,
      child: SizedBox(
        width: frameWidth,
        height: frameHeight,
        child: preset.showFrame
            ? _buildBezelFrame(context, frameWidth, frameHeight)
            : _buildDesktopFrame(context, frameWidth, frameHeight),
      ),
    );
  }

  /// Phone / tablet style: rounded bezel with notch + camera dot.
  Widget _buildBezelFrame(
    BuildContext context,
    double w,
    double h,
  ) {
    const double bezelRadius = 24.0;
    const double borderWidth = 2.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(bezelRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(bezelRadius),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(bezelRadius),
              border: Border.all(
                color: const Color(0xFF2A2A2A),
                width: borderWidth,
              ),
              color: const Color(0xFF111111),
            ),
            child: Stack(
              children: [
                // ---- Screen area (child) ----
                Positioned(
                  left: 4,
                  top: 4,
                  right: 4,
                  bottom: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(bezelRadius - 4),
                    child: child,
                  ),
                ),
                // ---- Notch cutout (top center) ----
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 120,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            border: const Border(
                              left: BorderSide(
                                color: Color(0xFF2A2A2A),
                                width: 1,
                              ),
                              right: BorderSide(
                                color: Color(0xFF2A2A2A),
                                width: 1,
                              ),
                              bottom: BorderSide(
                                color: Color(0xFF2A2A2A),
                                width: 1,
                              ),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF333333),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Desktop / monitor style: thin bezel + stand.
  Widget _buildDesktopFrame(
    BuildContext context,
    double w,
    double h,
  ) {
    const double bezelWidth = 3.0;

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- Monitor body ----
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: -1,
                ),
              ],
              border: Border.all(
                color: const Color(0xFF2A2A2A),
                width: bezelWidth,
              ),
              color: const Color(0xFF111111),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: child,
              ),
            ),
          ),
          // ---- Stand ----
          Container(
            width: 120,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
            ),
          ),
          // ---- Base ----
          Container(
            width: 180,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
