import 'package:flutter/material.dart';

class TransferProgressBar extends StatelessWidget {
  final int totalFrames;
  final Set<int> receivedIndices;

  const TransferProgressBar({
    super.key,
    required this.totalFrames,
    required this.receivedIndices,
  });

  @override
  Widget build(BuildContext context) {
    if (totalFrames == 0) return const SizedBox.shrink();

    final double completionRatio = receivedIndices.length / totalFrames;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Progress: ${receivedIndices.length} / $totalFrames Chunks",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            Text(
              "${(completionRatio * 100).toStringAsFixed(1)}%",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: completionRatio,
            minHeight: 10,
            backgroundColor: Colors.white12,
            color: Colors.deepPurpleAccent,
          ),
        ),
      ],
    );
  }
}