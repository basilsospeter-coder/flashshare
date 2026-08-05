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
  late MobileScannerController controller;

  bool _hasPermission = false;
  bool _isInitializing = true;
  bool _isSaving = false;

  String _debugErrorLog = "";

  final Map<int, String> _receivedChunks = {};
  int _totalChunks = 0;
  String _fileName = "";

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  Future<void> _initScanner() async {
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.unrestricted,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
      autoStart: false,
    );

    final status = await Permission.camera.request();

    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
      });

      try {
        await controller.start();
      } catch (e) {
        setState(() {
          _debugErrorLog = "Camera Start Error: $e";
        });
      }
    } else {
      setState(() {
        _hasPermission = false;
        _debugErrorLog = "Permission denied ($status). Enable in app settings.";
      });
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _restartCamera() async {
    setState(() {
      _isInitializing = true;
      _debugErrorLog = "";
    });

    try {
      await controller.stop();
      await controller.start();
    } catch (e) {
      setState(() {
        _debugErrorLog = "Restart Failure: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  void _processChunk(String rawData) {
    if (_isSaving) return;

    final parts = rawData.split('|');
    if (parts.length < 4) return;

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
      await controller.stop();

      StringBuffer sb = StringBuffer();
      for (int i = 0; i < _totalChunks; i++) {
        sb.write(_receivedChunks[i]);
      }

      Uint8List fileBytes = base64Decode(sb.toString());

      final Directory downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }

      final String filePath = '${downloadsDir.path}/$_fileName';
      final File savedFile = File(filePath);
      await savedFile.writeAsBytes(fileBytes);

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
              Navigator.pop(context);
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _totalChunks > 0
              ? 'Receiving (${_receivedChunks.length}/$_totalChunks)'
              : 'Align with Sender QR',
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (!_hasPermission) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 60, color: Colors.amber),
              const SizedBox(height: 16),
              const Text(
                'Camera Permission Required',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_debugErrorLog, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initScanner,
                child: const Text('Grant Camera Permission'),
              ),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open App Settings'),
              ),
            ],
          ),
        ),
      );
    }

    final double progress = _totalChunks > 0 ? (_receivedChunks.length / _totalChunks) : 0.0;

    return Stack(
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
            final dynamic ex = error;
            final String errorCode = ex.errorCode?.name ?? 'unknown';
            final String errorMessage = ex.errorDetails?.toString() ?? ex.toString();

            return Container(
              color: Colors.black,
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bug_report, color: Colors.redAccent, size: 60),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera Hardware Error',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Code: $errorCode', style: const TextStyle(color: Colors.yellowAccent)),
                          const SizedBox(height: 4),
                          Text('Details: $errorMessage', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Restart Camera Feed'),
                      onPressed: _restartCamera,
                    ),
                  ],
                ),
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
            color: Colors.black.withOpacity(0.7),
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
    );
  }
}