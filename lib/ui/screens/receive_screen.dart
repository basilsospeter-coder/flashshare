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
  MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.unrestricted,
    facing: CameraFacing.back,
    torchEnabled: false,
    returnImage: false,
  );

  bool _hasPermission = false;
  bool _isInitializing = true;
  bool _isSaving = false;

  // Detailed debug error capture
  String _debugErrorLog = "";

  final Map<int, String> _receivedChunks = {};
  int _totalChunks = 0;
  String _fileName = "";

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    debugPrint("[FlashShare Debug] Checking camera permissions...");
    final status = await Permission.camera.request();
    debugPrint("[FlashShare Debug] Camera Permission Status: $status");

    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
        _isInitializing = false;
      });
    } else {
      setState(() {
        _hasPermission = false;
        _isInitializing = false;
        _debugErrorLog = "Permission denied by OS ($status). Check App Settings.";
      });
    }
  }

  Future<void> _restartCamera() async {
    debugPrint("[FlashShare Debug] Resetting MobileScannerController...");
    setState(() {
      _isInitializing = true;
      _debugErrorLog = "";
    });

    try {
      await controller.dispose();
      controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.unrestricted,
        facing: CameraFacing.back,
        torchEnabled: false,
        returnImage: false,
      );
      await controller.start();
      debugPrint("[FlashShare Debug] Camera restarted successfully.");
    } catch (e, stack) {
      debugPrint("[FlashShare Debug] Error during camera restart: $e");
      debugPrint(stack.toString());
      setState(() {
        _debugErrorLog = "Restart Failure:\n$e";
      });
    } finally {
      setState(() {
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
      await controller.stop();

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
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasPermission) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 60, color: Colors.amber),
                const SizedBox(height: 16),
                const Text(
                  'Camera Permission Denied',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_debugErrorLog, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _checkPermissions,
                  child: const Text('Request Permission Again'),
                ),
                TextButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Open System App Settings'),
                ),
              ],
            ),
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
              // Extract detailed exception information
              final String errorCode = error.errorCode.name;
              final String errorMessage = error.message ?? "No detailed error message string provided";
              final Object? errorDetails = error.errorDetails;

              debugPrint("================ [MOBILE SCANNER CRASH] ================");
              debugPrint("Error Code: $errorCode");
              debugPrint("Message: $errorMessage");
              debugPrint("Details: $errorDetails");
              debugPrint("Raw Exception: $error");
              debugPrint("=========================================================");

              return Container(
                color: Colors.black,
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bug_report, color: Colors.redAccent, size: 60),
                        const SizedBox(height: 16),
                        const Text(
                          'Camera Engine Failed',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: SelectionArea(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Code: $errorCode', style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
                                const Divider(color: Colors.grey),
                                Text('Message: $errorMessage', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                if (errorDetails != null) ...[
                                  const SizedBox(height: 6),
                                  Text('Details: $errorDetails', style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Re-initialize Controller'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _restartCamera,
                        ),
                      ],
                    ),
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
      ),
    );
  }
}