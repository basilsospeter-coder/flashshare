import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const ReceiveScreen(),
    );
  }

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  bool _isScanned = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _hasPermission = status.isGranted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        centerTitle: true,
      ),
      body: !_hasPermission
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Camera permission is required to scan QR codes.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _requestPermission,
                    child: const Text('Grant Camera Permission'),
                  ),
                ],
              ),
            )
          : AiBarcodeScanner(
              onScan: (String code) {
                if (_isScanned) return;
                setState(() {
                  _isScanned = true;
                });

                debugPrint('QR Code Scanned: $code');

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Connected to: $code'),
                    backgroundColor: Colors.green,
                  ),
                );

                Navigator.pop(context, code);
              },
              onDetect: (BarcodeCapture capture) {
                // Additional detection callback if needed
              },
              canPop: true,
              showSuccessPage: false,
              hideSheetTitle: true,
            ),
    );
  }
}