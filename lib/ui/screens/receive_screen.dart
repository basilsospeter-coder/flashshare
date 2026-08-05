import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.unrestricted,
    facing: CameraFacing.back,
    torchEnabled: false,
    returnImage: false,
  );

  bool _hasPermission = false;
  bool _isInitializing = true;
  bool _isSaving = false;

  final Map<int, String> _receivedChunks = {};
  int _totalChunks = 0;
  String _fileName = "";

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
        _isInitializing = false;
      });
    } else {
      setState(() {
        _hasPermission = false;
        _isInitializing = false;
      });
    }
  }

  void _processChunk(String rawData) {
    if (_isSaving) return;

    final parts = rawData.split('|');
    if (parts.length < 4) return; // fileName|index|total|payload

    final String name = parts[0];
    final int index = int.tryParse(parts[1]) ?? -1;
    final int total = int.tryParse(parts[2]) ?? 0;
    final String payload = parts[3];

    if (index < 0 || total <= 0) return;

    if (_receivedChunks.isEmpty) {
      _fileName = name;
      _totalChunks = total;
    }

    if (!_receivedChunks.containsKey(index)) {
      setState(() {
        _receivedChunks[index] = payload;
      });

      if (_receivedChunks.length == _totalChunks) {
        _reassembleAndSaveFile();
      }
    }
  }

  Future<void> _reassembleAndSaveFile() async {
    setState(() {
      _isSaving = true;
    });

    try {
      controller.stop();

      // 1. Re-assemble Base64 stream sequentially
      StringBuffer sb = StringBuffer();
      for (int i = 0; i < _totalChunks; i++) {
        sb.write(_receivedChunks[i]);
      }

      // 2. Decode Base64 to raw file bytes
      Uint8List fileBytes = base64Decode(sb.toString());

      // 3. Save raw file directly to Downloads folder
      final Directory downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }

      final String filePath = '${downloadsDir.path}/$_fileName';
      final File savedFile = File(filePath);
      await savedFile.writeAsBytes(fileBytes);

      // 4. Register with Gal media gallery if applicable
      if (_isMediaFile(_fileName)) {
        await Gal.putImage(filePath);
      }

      if (mounted) {
        _showSuccessDialog(filePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving file: $e')),
        );
      }
    }
  }

  bool _isMediaFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov');
  }

  void _showSuccessDialog(String path) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Complete!'),
        content: Text('File successfully saved to:\n$path'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Return home
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasPermission) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Camera permission required to scan optical stream.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _checkPermissions,
                child: const Text('Grant Camera Permission'),
              ),
            ],
          ),
        ),
      );
    }

    final double progress = _totalChunks > 0 ? (_receivedChunks.length / _totalChunks) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _totalChunks > 0
              ? 'Receiving (${_receivedChunks.length}/$_totalChunks)'
              : 'Align with Sender QR',
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _processChunk(barcode.rawValue!);
                }
              }
            },
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      'Camera Error: ${error.errorCode}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => controller.start(),
                      child: const Text('Restart Camera'),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_totalChunks > 0)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Receiving: $_fileName',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}% (${_receivedChunks.length} / $_totalChunks chunks)',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          if (_isSaving)
            Container(
              color: Colors.black70,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Reassembling & saving file...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}