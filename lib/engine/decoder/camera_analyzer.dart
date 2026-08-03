// lib/engine/decoder/camera_analyzer.dart

import 'dart:typed_data';
import 'package:camera/camera.dart';
import '../../core/utils/checksum.dart';

class DecodedFrameResult {
  final int totalFrames;
  final int frameIndex;
  final bool isValid;
  final Uint8List? payload;

  DecodedFrameResult({
    required this.totalFrames,
    required this.frameIndex,
    required this.isValid,
    this.payload,
  });
}

class CameraAnalyzer {
  final int matrixSize;

  CameraAnalyzer({this.matrixSize = 32});

  /// Analyzes a live camera image stream frame to extract and decode BitMatrix payload.
  DecodedFrameResult? processCameraImage(CameraImage image) {
    try {
      // 1. Convert YUV420/BGRA image buffer to luminance/grayscale map
      final Uint8List luminancePlane = image.planes[0].bytes;
      final int width = image.width;
      final int height = image.height;

      // 2. Locate finder pattern anchors and threshold pixel values
      // (Simplified grid sampling logic for frame parsing)
      final List<List<bool>> sampledGrid = _sampleMatrixGrid(
        luminancePlane,
        width,
        height,
      );

      if (sampledGrid.isEmpty) return null;

      // 3. Extract binary header metadata and payload bytes from grid
      return _decodeGridToChunk(sampledGrid);
    } catch (e) {
      return null;
    }
  }

  List<List<bool>> _sampleMatrixGrid(Uint8List bytes, int width, int height) {
    // Basic thresholding and central ROI sampling
    final List<List<bool>> grid = List.generate(
      matrixSize,
      (_) => List.filled(matrixSize, false),
    );

    final int startX = (width * 0.2).toInt();
    final int startY = (height * 0.2).toInt();
    final double stepX = (width * 0.6) / matrixSize;
    final double stepY = (height * 0.6) / matrixSize;

    for (int y = 0; y < matrixSize; y++) {
      for (int x = 0; x < matrixSize; x++) {
        final int px = (startX + (x * stepX)).toInt();
        final int py = (startY + (y * stepY)).toInt();
        final int index = (py * width) + px;

        if (index < bytes.length) {
          // Dark pixel = true (1), Light pixel = false (0)
          grid[y][x] = bytes[index] < 128;
        }
      }
    }

    return grid;
  }

  DecodedFrameResult? _decodeGridToChunk(List<List<bool>> grid) {
    final List<int> extractedBits = [];

    for (int y = 0; y < matrixSize; y++) {
      for (int x = 0; x < matrixSize; x++) {
        // Skip 7x7 anchor patterns
        if (_isReservedArea(x, y)) continue;
        extractedBits.add(grid[y][x] ? 1 : 0);
      }
    }

    // Convert bits back to bytes
    final List<int> bytes = [];
    for (int i = 0; i < extractedBits.length - 7; i += 8) {
      int byte = 0;
      for (int b = 0; b < 8; b++) {
        byte = (byte << 1) | extractedBits[i + b];
      }
      bytes.add(byte);
    }

    if (bytes.length < 8) return null;

    final Uint8List rawData = Uint8List.fromList(bytes);
    final ByteData header = ByteData.sublistView(rawData, 0, 8);

    final int totalFrames = header.getUint16(0, Endian.big);
    final int frameIndex = header.getUint16(2, Endian.big);
    final int expectedCrc = header.getUint32(4, Endian.big);

    if (totalFrames == 0 || frameIndex >= totalFrames) return null;

    final Uint8List payload = rawData.sublist(8);
    final int actualCrc = ChecksumUtil.calculateCrc32(payload);

    return DecodedFrameResult(
      totalFrames: totalFrames,
      frameIndex: frameIndex,
      isValid: (expectedCrc == actualCrc),
      payload: payload,
    );
  }

  bool _isReservedArea(int x, int y) {
    bool inTopLeft = (x < 7 && y < 7);
    bool inTopRight = (x >= matrixSize - 7 && y < 7);
    bool inBottomLeft = (x < 7 && y >= matrixSize - 7);
    return inTopLeft || inTopRight || inBottomLeft;
  }
}