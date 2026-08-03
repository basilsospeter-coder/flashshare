import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/utils/file_chunker.dart';
import '../../engine/encoder/strobe_renderer.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  File? _selectedFile;
  List<Uint8List> _encodedChunks = [];
  bool _isProcessing = false;
  int _targetFps = 30;

  Future<void> _pickAndProcessFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      _isProcessing = true;
      _selectedFile = File(result.files.single.path!);
      _encodedChunks = [];
    });

    try {
      // Slice file into 256-byte chunks with headers and CRC32 checksums
      final chunks = await FileChunker.sliceFile(_selectedFile!, chunkSize: 256);
      setState(() {
        _encodedChunks = chunks;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error processing file: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Media'),
        actions: [
          if (_selectedFile != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _pickAndProcessFile,
              tooltip: 'Select Different File',
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              if (_selectedFile == null && !_isProcessing) ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.file_upload_outlined,
                          size: 90,
                          color: Colors.deepPurpleAccent,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Select a file to transmit",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Supports photos, videos, audio, APKs, or documents",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _pickAndProcessFile,
                          icon: const Icon(Icons.folder_open),
                          label: const Text("CHOOSE FILE"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (_isProcessing) ...[
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.deepPurpleAccent),
                        SizedBox(height: 20),
                        Text("Compressing and generating bit matrices..."),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Display File Meta Details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file, color: Colors.deepPurpleAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFile!.path.split('/').last,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "${(_selectedFile!.lengthSync() / 1024).toStringAsFixed(1)} KB • ${_encodedChunks.length} frames",
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Framerate Control Slider
                Row(
                  children: [
                    Text("FPS: $_targetFps", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Slider(
                        value: _targetFps.toDouble(),
                        min: 15,
                        max: 60,
                        divisions: 3,
                        label: "$_targetFps FPS",
                        activeColor: Colors.deepPurpleAccent,
                        onChanged: (val) {
                          setState(() => _targetFps = val.toInt());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Active Optical Strobe Display
                Expanded(
                  child: Center(
                    child: StrobeRenderer(
                      chunks: _encodedChunks,
                      matrixSize: 32,
                      targetFps: _targetFps,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}