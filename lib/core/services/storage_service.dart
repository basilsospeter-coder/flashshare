import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class StorageService {
  /// Request necessary storage and camera permissions on device
  static Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
    ].request();

    return statuses[Permission.camera]?.isGranted ?? false;
  }

  /// Get local app directory for saving received media
  static Future<Directory> getDownloadDirectory() async {
    Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir != null) return externalDir;
    return await getApplicationDocumentsDirectory();
  }

  /// Save raw byte payload to file on local storage
  static Future<File> saveFile(Uint8List bytes, String fileName) async {
    final Directory dir = await getDownloadDirectory();
    final String fullPath = "${dir.path}/$fileName";
    final File file = File(fullPath);
    return await file.writeAsBytes(bytes);
  }
}