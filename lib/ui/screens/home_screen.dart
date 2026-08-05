import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'send_screen.dart';
import 'receive_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _connectedPayload;

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);

    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SendScreen(
            fileBytes: file.bytes!,
            fileName: file.name,
          ),
        ),
      );
    }
  }

  void _startConnectionScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: 400,
        child: MobileScanner(
          controller: MobileScannerController(
            detectionSpeed: DetectionSpeed.noDuplicates,
            facing: CameraFacing.back,
          ),
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              if (barcode.rawValue != null) {
                final val = barcode.rawValue!;
                if (val.contains('flash_sender_connect_payload') || val.isNotEmpty) {
                  setState(() {
                    _connectedPayload = val;
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Connected! Pick a file to start sending.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _pickAndSendFile();
                  break;
                }
              }
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectedPayload != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flash Sender'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(
                Icons.flash_on,
                size: 80,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 16),
              const Text(
                'Fast Local Sharing',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send or receive files effortlessly using local peer-to-peer connection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // SEND CARD
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    child: Icon(Icons.send, color: Colors.white),
                  ),
                  title: const Text('Send', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Generate QR code & share files'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickAndSendFile,
                ),
              ),
              const SizedBox(height: 16),

              // RECEIVE CARD
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.qr_code_scanner, color: Colors.white),
                  ),
                  title: const Text('Receive', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Scan sender's QR code to connect"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ReceiveScreen(),
                      ),
                    );
                  },
                ),
              ),

              const Spacer(),

              // ACTION BUTTON WHEN CONNECTED
              if (isConnected) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _pickAndSendFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Select File to Send', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 16),
              ],

              // CONNECTION STATUS BAR
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isConnected
                      ? 'Connected to: $_connectedPayload'
                      : 'Tap "Send" or "Receive" to connect',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isConnected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}