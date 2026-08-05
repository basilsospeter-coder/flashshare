import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({Key? key}) : super(key: key);

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final Map<int, String> _receivedChunks = {};
  int _totalExpectedFrames = 0;
  bool _isComplete = false;

  void _handleBarcode(String rawValue) {
    if (_isComplete) return;

    try {
      final parts = rawValue.split('|');
      if (parts.length != 2) return;

      final headerParts = parts[0].split('/');
      final frameIndex = int.parse(headerParts[0]);
      final totalFrames = int.parse(headerParts[1]);

      if (_totalExpectedFrames == 0) {
        setState(() {
          _totalExpectedFrames = totalFrames;
        });
      }

      if (!_receivedChunks.containsKey(frameIndex)) {
        setState(() {
          _receivedChunks[frameIndex] = parts[1];
        });

        if (_receivedChunks.length == _totalExpectedFrames) {
          _assembleFile();
        }
      }
    } catch (e) {
      // Ignore unreadable frames during focus shifts
    }
  }

  void _assembleFile() {
    _isComplete = true;

    final StringBuffer fullBase64 = StringBuffer();
    for (int i = 0; i < _totalExpectedFrames; i++) {
      fullBase64.write(_receivedChunks[i]);
    }

    final Uint8List decodedBytes = base64Decode(fullBase64.toString());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File Transfer Complete! (${decodedBytes.length} bytes)'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _totalExpectedFrames > 0
        ? _receivedChunks.length / _totalExpectedFrames
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Optical Stream'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: MobileScannerController(
                detectionSpeed: DetectionSpeed.noDuplicates,
                facing: CameraFacing.back,
                formats: const [BarcodeFormat.qrCode],
              ),
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  if (barcode.rawValue != null) {
                    _handleBarcode(barcode.rawValue!);
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isComplete
                        ? 'Transfer Complete!'
                        : 'Captured: ${_receivedChunks.length} / $_totalExpectedFrames frames',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                  ),
                  const SizedBox(height: 8),
                  Text('${(progress * 100).toStringAsFixed(0)}% Captured'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}