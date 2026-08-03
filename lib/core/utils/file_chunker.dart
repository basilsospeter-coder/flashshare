import 'dart:io';
import 'dart:typed_data';
import 'checksum.dart';

class FileChunk {
  final int totalFrames;
  final int frameIndex;
  final int crc32;
  final Uint8List payload;

  FileChunk({
    required this.totalFrames,
    required this.frameIndex,
    required this.crc32,
    required this.payload,
  });
}

class FileChunker {
  /// Slices a file into transport-ready binary chunks with metadata headers.
  static Future<List<Uint8List>> sliceFile(File file, {int chunkSize = 256}) async {
    final Uint8List bytes = await file.readAsBytes();
    final int totalFrames = (bytes.length / chunkSize).ceil();
    final List<Uint8List> formattedFrames = [];

    for (int i = 0; i < totalFrames; i++) {
      final int start = i * chunkSize;
      final int end = (start + chunkSize < bytes.length) ? start + chunkSize : bytes.length;
      final Uint8List chunkData = bytes.sublist(start, end);
      final int crc = ChecksumUtil.calculateCrc32(chunkData);

      // Header structure: [Total Frames (2 bytes) | Index (2 bytes) | CRC32 (4 bytes) | Payload]
      final ByteData header = ByteData(8);
      header.setUint16(0, totalFrames, Endian.big);
      header.setUint16(2, i, Endian.big);
      header.setUint32(4, crc, Endian.big);

      final builder = BytesBuilder();
      builder.add(header.buffer.asUint8List());
      builder.add(chunkData);
      formattedFrames.add(builder.toBytes());
    }

    return formattedFrames;
  }

  /// Rebuilds full file payload from decoded chunks.
  static Uint8List reassemble(Map<int, Uint8List> chunksMap) {
    final builder = BytesBuilder();
    final sortedKeys = chunksMap.keys.toList()..sort();

    for (var key in sortedKeys) {
      builder.add(chunksMap[key]!);
    }

    return builder.toBytes();
  }
}