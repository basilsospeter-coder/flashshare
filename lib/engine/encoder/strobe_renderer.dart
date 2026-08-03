import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'bit_matrix.dart';

class StrobeRenderer extends StatefulWidget {
  final List<Uint8List> chunks;
  final int matrixSize;
  final int targetFps;
  final VoidCallback? onCompleted;

  const StrobeRenderer({
    super.key,
    required this.chunks,
    this.matrixSize = 32,
    this.targetFps = 30,
    this.onCompleted,
  });

  @override
  State<StrobeRenderer> createState() => _StrobeRendererState();
}

class _StrobeRendererState extends State<StrobeRenderer>
    with SingleTickerProviderStateMixin {
  late List<BitMatrix> _matrices;
  late Ticker _ticker;

  int _currentFrameIndex = 0;
  Duration _lastFrameTime = Duration.zero;
  late Duration _frameInterval;

  @override
  void initState() {
    super.initState();
    _frameInterval = Duration(microseconds: (1000000 / widget.targetFps).round());
    _buildMatrices();

    // High-precision ticker for cycling frames at target FPS
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _buildMatrices() {
    _matrices = widget.chunks
        .map((chunk) => BitMatrix.fromChunk(chunk, matrixSize: widget.matrixSize))
        .toList();
  }

  @override
  void didUpdateWidget(StrobeRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chunks != widget.chunks) {
      _buildMatrices();
      _currentFrameIndex = 0;
    }
    if (oldWidget.targetFps != widget.targetFps) {
      _frameInterval = Duration(microseconds: (1000000 / widget.targetFps).round());
    }
  }

  void _onTick(Duration elapsed) {
    if (_matrices.isEmpty) return;

    if (elapsed - _lastFrameTime >= _frameInterval) {
      _lastFrameTime = elapsed;
      setState(() {
        _currentFrameIndex = (_currentFrameIndex + 1) % _matrices.length;
      });

      if (_currentFrameIndex == 0 && widget.onCompleted != null) {
        widget.onCompleted!();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_matrices.isEmpty) {
      return const Center(child: Text("No data to transmit"));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: CustomPaint(
            painter: BitMatrixPainter(matrix: _matrices[_currentFrameIndex]),
            child: Container(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Transmitting Frame ${_currentFrameIndex + 1} / ${_matrices.length}",
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}

/// Custom painter to draw the 2D bit grid onto the device screen
class BitMatrixPainter extends CustomPainter {
  final BitMatrix matrix;

  BitMatrixPainter({required this.matrix});

  @override
  void paint(Canvas canvas, Size size) {
    final double cellSize = size.width / matrix.size;

    final Paint blackPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Fill background white
    canvas.drawRect(Offset.zero & size, whitePaint);

    // Draw individual matrix cells
    for (int y = 0; y < matrix.size; y++) {
      for (int x = 0; x < matrix.size; x++) {
        if (matrix.grid[y][x]) {
          final Rect rect = Rect.fromLTWH(
            x * cellSize,
            y * cellSize,
            cellSize,
            cellSize,
          );
          canvas.drawRect(rect, blackPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BitMatrixPainter oldDelegate) {
    return oldDelegate.matrix != matrix;
  }
}