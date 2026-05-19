/// A device preset that defines the viewport dimensions, icon, scale, and
/// whether a device bezel frame should be rendered around the preview.
class DevicePreset {
  /// Human-readable device name (e.g., "Phone", "Tablet").
  final String name;

  /// Viewport width in logical pixels.
  final double width;

  /// Viewport height in logical pixels.
  final double height;

  /// Emoji icon used in the selector chip.
  final String icon;

  /// Preview scale factor applied to the entire device frame so it fits the
  /// available screen area.
  final double scale;

  /// Whether to render a device bezel frame (rounded corners, notch, etc.).
  final bool showFrame;

  const DevicePreset({
    required this.name,
    required this.width,
    required this.height,
    required this.icon,
    required this.scale,
    required this.showFrame,
  });

  /// The four built-in device presets.
  static const List<DevicePreset> presets = [
    DevicePreset(
      name: 'Phone',
      width: 390,
      height: 844,
      icon: '📱',
      scale: 0.85,
      showFrame: true,
    ),
    DevicePreset(
      name: 'Fold',
      width: 717,
      height: 512,
      icon: '📂',
      scale: 0.7,
      showFrame: true,
    ),
    DevicePreset(
      name: 'Tablet',
      width: 820,
      height: 1180,
      icon: '📟',
      scale: 0.6,
      showFrame: true,
    ),
    DevicePreset(
      name: 'Desktop',
      width: 1440,
      height: 900,
      icon: '🖥️',
      scale: 0.45,
      showFrame: false,
    ),
  ];
}
