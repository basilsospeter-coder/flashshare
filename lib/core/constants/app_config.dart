class AppConfig {
  static const String appName = "FlashShare";
  
  // Matrix and Strobe Transmission Parameters
  static const int defaultMatrixSize = 32; // 32x32 grid
  static const int defaultChunkSize = 256;  // 256 bytes per optical frame
  static const int defaultFps = 30;         // Target transmission rate
  static const int maxFps = 60;
  
  // Optical Protocol Headers
  static const int headerSizeBytes = 8;     // [Total (2B) | Index (2B) | CRC32 (4B)]
  
  // Colors for Matrix Visualization
  static const int darkThreshold = 128;     // Luminance threshold for camera analysis
}