/// Placeholder service for LiteRT (TensorFlow Lite) runtime.
///
/// This singleton will be wired to the actual LiteRT / TFLite runtime
/// in a future phase. For now all methods return `null` / `false`.
class LiteRTRuntime {
  LiteRTRuntime._();
  static final LiteRTRuntime _instance = LiteRTRuntime._();
  static LiteRTRuntime get instance => _instance;

  /// Whether the LiteRT runtime is available on this device.
  ///
  /// Returns `false` until the native TFLite library is bundled.
  Future<bool> isAvailable() async => false;

  /// Load a TFLite model by [name].
  ///
  /// The model must have been previously downloaded via [ModelDownloadService].
  Future<void> loadModel(String name) async {
    // Placeholder — will invoke TFLite interpreter in a later phase.
  }

  /// Run inference with the loaded model.
  ///
  /// Accepts a map of input tensors (name → data) and returns a map of
  /// output tensors, or `null` if no model is loaded.
  Future<Map<String, dynamic>?> runInference(
    Map<String, dynamic> input,
  ) async {
    return null;
  }
}
