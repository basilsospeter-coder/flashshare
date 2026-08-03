import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'ui/screens/home_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Obtain list of available cameras on application startup
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Camera initialization error: $e');
  }

  runApp(const FlashShareApp());
}

class FlashShareApp extends StatelessWidget {
  const FlashShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlashShare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: HomeScreen(cameras: cameras),
    );
  }
}