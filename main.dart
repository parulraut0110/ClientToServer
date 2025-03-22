import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras(); // Get available cameras
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Y Plane Upload')),
        body: CameraPreviewScreen(),
      ),
    );
  }
}

class CameraPreviewScreen extends StatefulWidget {
  @override
  _CameraPreviewScreenState createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  CameraController? _controller;
  bool _isSending = false;

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
        cameras![1], // Use the second available camera
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.yuv420, // YUV format
      );

      await _controller!.initialize();

      if (!mounted) return;
      setState(() {});

      // Start image stream
      _controller!.startImageStream((CameraImage image) {
        if (!_isSending) {
          _isSending = true;
          sendYUVPlanesToServer(image).then((_) {
            _isSending = false; // Reset the flag after sending
          });
        }
      });
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> sendYUVPlanesToServer(CameraImage image) async {
    try {
      // Extract the Y plane from the YUV image
      Uint8List yPlane = image.planes[0].bytes;
      Uint8List uPlane = image.planes[1].bytes;
      Uint8List vPlane = image.planes[2].bytes;

      // Get the stride (bytes per row) for the Y plane
      int yStride = image.planes[0].bytesPerRow;
      int uvStride = image.planes[1].bytesPerRow;

      // Debug: Log Y plane size, stride, width, and height
      print('Y plane size: ${yPlane.length}');
      print('U plane size: ${uPlane.length}');
      print('V plane size: ${vPlane.length}');
      print('Y plane stride: $yStride');
      print('U plane stride: $uvStride');
      print('Image width: ${image.width}');
      print('Image height: ${image.height}');

      int uvplane_height = image.height ~/ 2;
      int uvplane_width = image.width ~/ 2;
      int uvplane_length = uPlane.length;

      // Create a zero-filled array of size height * width
      Uint8List yPlanePadded = Uint8List(image.height * image.width);
      Uint8List uPlanePadded = Uint8List(uvplane_height * uvplane_width);
      Uint8List vPlanePadded = Uint8List(uvplane_height * uvplane_width);

      // Fill the padded array with zeros
      yPlanePadded.fillRange(0, yPlanePadded.length, 0);
      uPlanePadded.fillRange(0, uPlanePadded.length, 0);
      vPlanePadded.fillRange(0, vPlanePadded.length, 0);
      /*
      if (yPlane.length != image.width * image.height ||
          uPlane.length != uvplane_width * uvplane_height ||
          vPlane.length != uPlane.length) {
        print("Y/U/V plane size mismatch");
        return;
      }
*/
      // Populate the padded array with values from the Y plane
      for (int row = 0; row < image.height; row++) {
        for (int col = 0; col < image.width; col++) {
          int index = row * yStride + col;
          if (index < yPlane.length) {
            yPlanePadded[row * image.width + col] = yPlane[index];
          }
        }
      }

      // U plane processing
      for (int row = 0; row < uvplane_height; row++) {
        for (int col = 0; col < uvplane_width; col++) {
          int index = row * uvStride + col;
          if (index < uPlane.length) {
            uPlanePadded[row * uvplane_width + col] = uPlane[index];
          }
        }
      }

      // V plane processing
      for (int row = 0; row < uvplane_height; row++) {
        for (int col = 0; col < uvplane_width; col++) {
          int index = row * uvStride + col;
          if (index < vPlane.length) {
            vPlanePadded[row * uvplane_width + col] = vPlane[index];
          }
        }
      }

      // Debug: Log the padded Y plane size
      print('Padded Y plane size: ${yPlanePadded.length}');

      //print('uPlane: ... $uPlanePadded.sublist(uPlane.length - 10)');
      //print('vPlane: ... $vPlanePadded.sublist(0, 10)');

      // Create a multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("http://192.168.136.236:5000/process_raw_frame"),
      );

      // Attach the padded Y plane as a file
      request.files.add(
        http.MultipartFile.fromBytes(
          'yPlane',
          yPlanePadded,
          filename: 'yPlane.bin',
        ),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'uPlane',
          uPlanePadded,
          filename: 'uPlane.bin',
        ),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'vPlane',
          vPlanePadded,
          filename: 'vPlane.bin',
        ),
      );

      // Add width, height, and stride as form data
      request.fields['width'] = image.width.toString();
      request.fields['height'] = image.height.toString();
      request.fields['yStride'] = yStride.toString();
      request.fields['uvStride'] = uvStride.toString();

      // Send the request
      var response = await request.send();

      // Check the response
      if (response.statusCode == 200) {
        print("Y plane sent successfully");
      } else {
        print("Error sending Y plane: ${response.statusCode}");
        print("Response body: ${await response.stream.bytesToString()}");
      }
    } catch (e) {
      print("Error in sendYPlaneToServer: $e");
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
