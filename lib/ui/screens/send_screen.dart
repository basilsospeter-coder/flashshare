import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SendScreen extends StatefulWidget {
  final Uint8List fileBytes;
  final String fileName;

  const SendScreen({
    Key? key,
    required this.fileBytes,
    required this.fileName,
  }) : super(key: key);

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  List<String> _qrFrames = [];
  int _currentFrameIndex = 0;
  Timer? _transmissionTimer;

  // SPEED ENGINE: 700 bytes chunk size + 100ms update rate (~10 FPS)
  static const int _chunkSize = 700;
  static const int _frameIntervalMs = 100;

  @override
  void initState() {
    super.initState();
    _prepareFrames();
    _startTransmission();
  }

  void _prepareFrames() {
    final StringBuffer hexBuffer = StringBuffer();
    for (int b in widget.fileBytes) {
      hexBuffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    final String hexData = hexBuffer.toString();

    final List<String> rawChunks = [];
    final int hexChunkSize = _chunkSize * 2;

    for (int i = 0; i < hexData.length; i += hexChunkSize) {
      int end = (i + hexChunkSize < hexData.length)
          ? i + hexChunkSize
          : hexData.length;
      rawChunks.add(hexData.substring(i, end));
    }

    final int totalFrames = rawChunks.length;

    _qrFrames = List.generate(totalFrames, (index) {
      return '${widget.fileName}|$index/$totalFrames|${rawChunks[index]}';
    });
  }

  void _startTransmission() {
    _transmissionTimer?.cancel();
    _transmissionTimer = Timer.periodic(
      const Duration(milliseconds: _frameIntervalMs),
      (timer) {
        if (_qrFrames.isNotEmpty) {
          setState(() {
            _currentFrameIndex = (_currentFrameIndex + 1) % _qrFrames.length;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _transmissionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_qrFrames.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final double progress = (_currentFrameIndex + 1) / _qrFrames.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transmitting File'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.fileName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Frame ${_currentFrameIndex + 1} of ${_qrFrames.length}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: _qrFrames[_currentFrameIndex],
                  version: QrVersions.auto,
                  size: 300.0,
                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('${(progress * 100).toStringAsFixed(0)}% Streaming'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}