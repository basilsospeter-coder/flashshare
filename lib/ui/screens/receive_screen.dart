import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  MobileScannerController? _controller;
  bool _hasCameraPermission = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  Future<void> _initScanner() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() {
        _hasCameraPermission = true;
        _controller = MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
          torchEnabled: false,
        );
      });
    } else {
      setState(() {
        _errorMessage = 'Camera permission was denied.';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          if (_controller != null) ...[
            IconButton(
              icon: ValueListenableBuilder(
                valueListenable: _controller!,
                builder: (context, state, child) {
                  return Icon(
                    state.torchState == TorchState.on
                        ? Icons.flash_on
                        : Icons.flash_off,
                  );
                },
              ),
              onPressed: () => _controller?.toggleTorch(),
            ),
            IconButton(
              icon: const Icon(Icons.cameraswitch),
              onPressed: () => _controller?.switchCamera(),
            ),
          ],
        ],
      ),
      body: Builder(
        builder: (context) {
          if (!_hasCameraPermission) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage ?? 'Requesting camera permission...',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initScanner,
                    child: const Text('Grant Permission'),
                  ),
                ],
              ),
            );
          }

          if (_controller == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                    Navigator.pop(context, barcodes.first.rawValue);
                  }
                },
                errorBuilder: (context, error, child) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.red, size: 60),
                          const SizedBox(height: 16),
                          Text(
                            'Camera Error Code:\n${error.errorCode}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            'Details: ${error.errorDetails?.message ?? error.toString()}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              _controller?.start();
                            },
                            child: const Text('Restart Camera'),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.purple, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}