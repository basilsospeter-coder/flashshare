// lib/ui/screens/receive_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/file_chunker.dart';
import '../../engine/decoder/camera_analyzer.dart';

class ReceiveScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ReceiveScreen({super.key, required this.cameras});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  CameraController? _cameraController;
  late CameraAnalyzer _analyzer;

  final Map<int, Uint8List> _receivedChunks = {};
  int _totalFrames = 0;
  bool _isProcessingFrame = false;
  bool _isComplete = false;
  String? _savedFilePath;

  @override
  void initState() {
    super.initState();
    _analyzer = CameraAnalyzer(matrixSize: 32);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    _cameraController = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      await _cameraController!.setFocusMode(FocusMode.locked);
      await _cameraController!.setExposureMode(ExposureMode.locked);

      await _cameraController!.startImageStream((CameraImage image) {
        if (_isProcessingFrame || _isComplete) return;
        _isProcessingFrame = true;

        final result = _analyzer.processCameraImage(image);
        if (result != null && result.isValid && result.payload != null) {
          _handleDecodedChunk(result);
        }

        _isProcessingFrame = false;
      });

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera startup error: $e");
    }
  }

  void _handleDecodedChunk(DecodedFrameResult result) {
    if (!_receivedChunks.containsKey(result.frameIndex)) {
      setState(() {
        _totalFrames = result.totalFrames;
        _receivedChunks[result.frameIndex] = result.payload!;
      });

      if (_receivedChunks.length == _totalFrames && _totalFrames > 0) {
        _finalizeFileDownload();
      }
    }
  }

  Future<void> _finalizeFileDownload() async {
    setState(() => _isComplete = true);
    await _cameraController?.stopImageStream();

    final Uint8List fileBytes = FileChunker.reassemble(_receivedChunks);
    final Directory dir = await getApplicationDocumentsDirectory();
    final String path = "${dir.path}/received_file_${DateTime.now().millisecondsSinceEpoch}.bin";

    final File savedFile = File(path);
    await savedFile.writeAsBytes(fileBytes);

    setState(() {
      _savedFilePath = path;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _totalFrames > 0 ? (_receivedChunks.length / _totalFrames) : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Receive Media')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (_cameraController != null && _cameraController!.value.isInitialized)
                    CameraPreview(_cameraController!)
                  else
                    const Center(child: CircularProgressIndicator()),

                  // Scan Target Overlay Box
                  Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isComplete ? Colors.green : Colors.deepPurpleAccent,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Progress Dashboard
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.black87,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white24,
                    color: Colors.deepPurpleAccent,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isComplete
                            ? "Download Finished!"
                            : "Captured: ${_receivedChunks.length} / ${_totalFrames == 0 ? '--' : _totalFrames} frames",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text("${(progress * 100).toStringAsFixed(0)}%"),
                    ],
                  ),
                  if (_savedFilePath != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Saved to: $_savedFilePath",
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}