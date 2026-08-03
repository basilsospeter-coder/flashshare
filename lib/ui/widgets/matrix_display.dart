import 'package:flutter/material.dart';
import '../../engine/encoder/bit_matrix.dart';
import '../../engine/encoder/strobe_renderer.dart';

class MatrixDisplay extends StatelessWidget {
  final BitMatrix matrix;

  const MatrixDisplay({super.key, required this.matrix});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: CustomPaint(
        painter: BitMatrixPainter(matrix: matrix),
        child: Container(),
      ),
    );
  }
}