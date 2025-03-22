import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: CameraScreen());
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isFirstFrame = true; // Flag to track the first frame

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    if (cameras == null || cameras!.isEmpty) {
      print("No camera found");
      return;
    }

    try {
      _controller = CameraController(
        cameras![1], // Use the first available camera
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.yuv420, // YUV format
      );

      await _controller!.initialize();

      if (!mounted) return;
      setState(() {});

      // Start image stream
      _controller!.startImageStream((CameraImage image) {
        if (_isFirstFrame) {
          saveYUVData(image); // Save YUV data for the first frame
          _isFirstFrame = false; // Update the flag
        }
      });
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return CameraPreview(_controller!);
  }
}

Future<void> saveYUVData(CameraImage image) async {
  // Get the external storage directory (e.g., Downloads folder)
  final directory = await getExternalStorageDirectory();

  // Add phone model name and Android version to the file path
  String phoneModel = "Redmi_10"; // Replace with your phone model name
  String androidVersion =
      "Android_13_TKQ1"; // Replace with your Android version
  String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

  // Construct file paths in the Downloads directory
  String yPlanePath =
      '${directory!.path}/Download/${phoneModel}${androidVersion}_y_plane$timestamp.bin';
  String uPlanePath =
      '${directory.path}/Download/${phoneModel}${androidVersion}_u_plane$timestamp.bin';
  String vPlanePath =
      '${directory.path}/Download/${phoneModel}${androidVersion}_v_plane$timestamp.bin';

  // Ensure the Download directory exists
  Directory('${directory.path}/Download').createSync(recursive: true);

  // Save Y plane
  File(yPlanePath).writeAsBytesSync(image.planes[0].bytes);

  // Save U plane
  File(uPlanePath).writeAsBytesSync(image.planes[1].bytes);

  // Save V plane
  File(vPlanePath).writeAsBytesSync(image.planes[2].bytes);

  // Print full file paths
  print('Y plane saved to: $yPlanePath');
  print('U plane saved to: $uPlanePath');
  print('V plane saved to: $vPlanePath');

  // Print file lengths
  print('Y plane length: ${File(yPlanePath).lengthSync()} bytes');
  print('U plane length: ${File(uPlanePath).lengthSync()} bytes');
  print('V plane length: ${File(vPlanePath).lengthSync()} bytes');
}


stores the plane data in phone
