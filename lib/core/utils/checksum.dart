import 'dart:typed_data';

class ChecksumUtil {
  /// Calculates a standard CRC32 checksum for a given byte array.
  static int calculateCrc32(Uint8List data) {
    int crc = 0xFFFFFFFF;
    for (int i = 0; i < data.length; i++) {
      int byte = data[i];
      crc ^= byte;
      for (int j = 0; j < 8; j++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xEDB88320;
        } else {
          crc = crc >> 1;
        }
      }
    }
    return (crc ^ 0xFFFFFFFF) >>> 0;
  }
}