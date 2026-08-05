import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SendScreen extends StatefulWidget {
  final Uint8List fileBytes;
  final String fileName;

  const SendScreen({
    super.key,
    required this.fileBytes,
    required this.fileName,
  });

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  List<String> _qrChunks = [];
  int _currentIndex = 0;
  Timer? _streamTimer;

  // BUFFED CONFIGURATION
  static const int chunkSize = 1400; // ~1.4KB payload per frame
  static const Duration frameInterval = Duration(milliseconds: 40); // 25 FPS

  @override
  void initState() {
    super.initState();
    _prepareChunks();
    _startStreaming();
  }

  void _prepareChunks() {
    // 1. Encode file bytes directly to Base64
    final String base64Data = base64Encode(widget.fileBytes);
    final int totalLength = base64Data.length;
    final int totalChunks = (totalLength / chunkSize).ceil();

    List<String> chunks = [];
    for (int i = 0; i < totalChunks; i++) {
      int start = i * chunkSize;
      int end = (start + chunkSize < totalLength) ? start + chunkSize : totalLength;
      String payload = base64Data.substring(start, end);

      // Header: fileName|index|total|payload
      chunks.add('${widget.fileName}|$i|$totalChunks|$payload');
    }

    setState(() {
      _qrChunks = chunks;
    });
  }

  void _startStreaming() {
    _streamTimer = Timer.periodic(frameInterval, (timer) {
      if (_qrChunks.isNotEmpty) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _qrChunks.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_qrChunks.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final double progress = ((_currentIndex + 1) / _qrChunks.length) * 100;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Streaming FlashShare (${_currentIndex + 1}/${_qrChunks.length})',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _qrChunks.length,
              backgroundColor: Colors.grey[900],
              color: Colors.blueAccent,
            ),
            Expanded(
              child: Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: _qrChunks[_currentIndex],
                    version: QrVersions.auto,
                    size: 340.0,
                    gapless: false,
                    errorCorrectionLevel: QrErrorCorrectLevel.L,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                'Streaming Frame Rate: ~25 FPS | ${progress.toStringAsFixed(1)}% Loop',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}