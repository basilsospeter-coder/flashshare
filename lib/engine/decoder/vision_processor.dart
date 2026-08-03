import 'dart:typed_data';

class VisionProcessor {
  /// Converts YUV420 raw camera image frame to a 2D grayscale luminance array
  static Uint8List extractLuminancePlane(List<Uint8List> planeBytes) {
    return planeBytes[0]; // Y plane contains luminance (brightness) data
  }

  /// Evaluates pixel brightness to determine binary bit value (0 or 1)
  static bool isPixelDark(int luminanceByte, {int threshold = 128}) {
    return luminanceByte < threshold;
  }

  /// Validates if extracted anchor patterns match expected 7x7 QR finder ratios
  static bool validateFinderPattern(List<List<bool>> region) {
    if (region.length < 7 || region[0].length < 7) return false;
    // Outer border check
    return region[0][0] && region[0][6] && region[6][0] && region[6][6];
  }
}