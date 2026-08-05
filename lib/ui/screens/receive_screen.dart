import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({Key? key}) : super(key: key);

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final Map<int, String> _receivedChunks = {};
  int _totalExpectedFrames = 0;
  String _fileName = 'received_file';
  bool _isComplete = false;
  String _savedPath = '';

  void _handleBarcode(String rawValue) {
    if (_isComplete) return;

    try {
      final parts = rawValue.split('|');
      if (parts.length != 3) return;

      final fileName = parts[0];
      final headerParts = parts[1].split('/');
      final frameIndex = int.parse(headerParts[0]);
      final totalFrames = int.parse(headerParts[1]);

      if (_totalExpectedFrames == 0) {
        setState(() {
          _fileName = fileName;
          _totalExpectedFrames = totalFrames;
        });
      }

      if (!_receivedChunks.containsKey(frameIndex)) {
        setState(() {
          _receivedChunks[frameIndex] = parts[2];
        });

        if (_receivedChunks.length == _totalExpectedFrames) {
          _saveFileToStorage();
        }
      }
    } catch (e) {
      // Ignore corrupted frames during camera movement
    }
  }

  Future<void> _saveFileToStorage() async {
    _isComplete = true;

    // Request permissions
    await Permission.storage.request();

    final StringBuffer fullHex = StringBuffer();
    for (int i = 0; i < _totalExpectedFrames; i++) {
      fullHex.write(_receivedChunks[i]);
    }

    final String hexStr = fullHex.toString();
    final List<int> bytes = [];
    for (int i = 0; i < hexStr.length; i += 2) {
      bytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
    }
    final Uint8List fileBytes = Uint8List.fromList(bytes);

    // Write to Downloads directory
    Directory? storageDir;
    if (Platform.isAndroid) {
      storageDir = Directory('/storage/emulated/0/Download');
      if (!await storageDir.exists()) {
        storageDir = await getExternalStorageDirectory();
      }
    } else {
      storageDir = await getApplicationDocumentsDirectory();
    }

    final File file = File('${storageDir!.path}/$_fileName');
    await file.writeAsBytes(fileBytes);

    // Register media files so they show up directly in Gallery
    final String extension = _fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'mkv'].contains(extension)) {
      try {
        if (['mp4', 'mov', 'mkv'].contains(extension)) {
          await Gal.putVideo(file.path);
        } else {
          await Gal.putImage(file.path);
        }
      } catch (e) {
        // Fallback gracefully if indexing fails
      }
    }

    setState(() {
      _savedPath = file.path;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved: ${file.path}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
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
                        ? 'Saved to Downloads & Gallery!'
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
                  if (_savedPath.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Path: $_savedPath',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}