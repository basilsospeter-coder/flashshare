import 'dart:async';
import 'dart:convert';
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

  static const int _chunkSize = 180;
  static const int _frameIntervalMs = 220;

  @override
  void initState() {
    super.initState();
    _prepareFrames();
    _startTransmission();
  }

  void _prepareFrames() {
    final String base64Data = base64Encode(widget.fileBytes);
    final List<String> rawChunks = [];

    for (int i = 0; i < base64Data.length; i += _chunkSize) {
      int end = (i + _chunkSize < base64Data.length)
          ? i + _chunkSize
          : base64Data.length;
      rawChunks.add(base64Data.substring(i, end));
    }

    final int totalFrames = rawChunks.length;

    _qrFrames = List.generate(totalFrames, (index) {
      return '$index/$totalFrames|${rawChunks[index]}';
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
            const SizedBox(height: 24),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: _qrFrames[_currentFrameIndex],
                  version: QrVersions.auto,
                  size: 280.0,
                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('${(progress * 100).toStringAsFixed(0)}% Looping Stream'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}