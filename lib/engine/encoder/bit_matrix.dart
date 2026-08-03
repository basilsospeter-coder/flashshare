import 'dart:typed_data';

class BitMatrix {
  final int size; // Grid width and height (e.g., 32x32)
  late List<List<bool>> grid;

  BitMatrix({this.size = 32}) {
    // Initialize an empty grid (false = white / 0, true = black / 1)
    grid = List.generate(size, (_) => List.filled(size, false));
  }

  /// Converts a binary chunk into a 2D bit matrix with alignment anchors.
  static BitMatrix fromChunk(Uint8List chunkData, {int matrixSize = 32}) {
    final matrix = BitMatrix(size: matrixSize);

    // 1. Draw corner anchor markers (7x7 finder patterns) for camera tracking
    matrix._addFinderPattern(0, 0); // Top-Left
    matrix._addFinderPattern(matrixSize - 7, 0); // Top-Right
    matrix._addFinderPattern(0, matrixSize - 7); // Bottom-Left

    // 2. Map payload bits into available grid cells
    int byteIndex = 0;
    int bitIndex = 0;

    for (int y = 0; y < matrixSize; y++) {
      for (int x = 0; x < matrixSize; x++) {
        // Skip reserved regions occupied by anchor patterns
        if (matrix._isReservedArea(x, y, matrixSize)) continue;

        if (byteIndex < chunkData.length) {
          final int byteValue = chunkData[byteIndex];
          // Extract bit value at current bitIndex position (MSB to LSB)
          final bool bit = ((byteValue >> (7 - bitIndex)) & 1) == 1;
          matrix.grid[y][x] = bit;

          bitIndex++;
          if (bitIndex == 8) {
            bitIndex = 0;
            byteIndex++;
          }
        } else {
          // Fill remaining space with alternating padding bits
          matrix.grid[y][x] = (x + y) % 2 == 0;
        }
      }
    }

    return matrix;
  }

  /// Draws a 7x7 nested square anchor pattern (similar to QR finder patterns)
  void _addFinderPattern(int startX, int startY) {
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 7; c++) {
        if (r == 0 || r == 6 || c == 0 || c == 6) {
          grid[startY + r][startX + c] = true; // Outer black border
        } else if (r >= 2 && r <= 4 && c >= 2 && c <= 4) {
          grid[startY + r][startX + c] = true; // Inner black center square
        } else {
          grid[startY + r][startX + c] = false; // White inner ring
        }
      }
    }
  }

  /// Checks if a cell coordinate falls inside one of the three 7x7 anchor regions
  bool _isReservedArea(int x, int y, int matrixSize) {
    bool inTopLeft = (x < 7 && y < 7);
    bool inTopRight = (x >= matrixSize - 7 && y < 7);
    bool inBottomLeft = (x < 7 && y >= matrixSize - 7);
    return inTopLeft || inTopRight || inBottomLeft;
  }
}