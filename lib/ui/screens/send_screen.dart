import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SendScreen extends StatefulWidget {
  final String qrData;

  const SendScreen({
    super.key,
    this.qrData = 'flash_sender_connect_payload',
  });

  @style
  static Route<void> route({String qrData = 'flash_sender_connect_payload'}) {
    return MaterialPageRoute<void>(
      builder: (_) => SendScreen(qrData: qrData),
    );
  }

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Files'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Scan to Connect',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Have the receiver scan this QR code to establish connection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Center(
              child: QrImageView(
                data: widget.qrData,
                version: QrVersions.auto,
                size: 260.0,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Logic to pick files or trigger transfer
              },
              icon: const Icon(Icons.attach_file),
              label: const Text('Select Files to Send'),
            ),
          ],
        ),
      ),
    );
  }
}