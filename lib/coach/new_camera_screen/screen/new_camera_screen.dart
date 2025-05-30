// import 'package:camerawesome/camerawesome_plugin.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import '../server/digit_recognition.dart';
// // import 'package:flutter/rendering.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:camerawesome/pigeon.dart';
// import 'dart:io';

// class CameraPage extends StatelessWidget {
//   const CameraPage({super.key});

//   // Function to get coordinates for green squares
//   Future<List<List<Offset>>> getGreenSquareCoordinates(XFile image) async {
//     final list_of_coordinates = await get_digit_bounding_boxes(image);
//     return list_of_coordinates.map((coordinates) => [
//       Offset(coordinates[0].toDouble(), coordinates[1].toDouble()),
//       Offset(coordinates[2].toDouble(), coordinates[3].toDouble())
//     ]).toList();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: CameraAwesomeBuilder.previewOnly(
//           // 2.
//           previewFit: CameraPreviewFit.contain,
//           sensorConfig: SensorConfig.single(
//             sensor: Sensor.position(SensorPosition.front),
//             aspectRatio: CameraAspectRatios.ratio_1_1,
//           ),
//           // 3.
//           onImageForAnalysis: (img) => _analyzeImage(img),
//           // 4.
//           imageAnalysisConfig: AnalysisConfig(
//             androidOptions: const AndroidAnalysisOptions.nv21(
//               width: 250,
//             ),
//             maxFramesPerSecond: 5, // depending on your phone performances
//           ),
//           // 5.
//           builder: (state, previewSize, previewRect) {
//             return _MyPreviewDecoratorWidget(
//               cameraState: state,
//               faceDetectionStream: _faceDetectionController,
//               previewSize: previewSize,
//               previewRect: previewRect,
//             );
//           },
//         ),
//         // child: CameraAwesomeBuilder.custom(
//         //   onMediaCaptureEvent: (event) {
//         //     switch ((event.status, event.isPicture, event.isVideo)) {
//         //       case (MediaCaptureStatus.capturing, true, false):
//         //         Logger.d('Capturing picture...');
//         //       case (MediaCaptureStatus.success, true, false):
//         //         event.captureRequest.when(
//         //           single: (single) {
//         //             Logger.d('Picture saved: ${single.file?.path}');
//         //           },
//         //           multiple: (multiple) {
//         //             multiple.fileBySensor.forEach((key, value) {
//         //               Logger.d('multiple image taken: $key ${value?.path}');
//         //             });
//         //           },
//         //         );
//         //       case (MediaCaptureStatus.failure, true, false):
//         //         Logger.d('Failed to capture picture: ${event.exception}');
//         //       case (MediaCaptureStatus.capturing, false, true):
//         //         Logger.d('Capturing video...');
//         //       case (MediaCaptureStatus.success, false, true):
//         //         event.captureRequest.when(
//         //           single: (single) {
//         //             Logger.d('Video saved: ${single.file?.path}');
//         //           },
//         //           multiple: (multiple) {
//         //             multiple.fileBySensor.forEach((key, value) {
//         //               Logger.d('multiple video taken: $key ${value?.path}');
//         //             });
//         //           },
//         //         );
//         //       case (MediaCaptureStatus.failure, false, true):
//         //         Logger.d('Failed to capture video: ${event.exception}');
//         //       default:
//         //         Logger.d('Unknown event: $event');
//         //     }
//         //   },
//         //   saveConfig: SaveConfig.photoAndVideo(
//         //     initialCaptureMode: CaptureMode.photo,
//         //     photoPathBuilder: (sensors) async {
//         //       final Directory extDir = await getTemporaryDirectory();
//         //       final testDir = await Directory(
//         //         '${extDir.path}/camerawesome',
//         //       ).create(recursive: true);
//         //       if (sensors.length == 1) {
//         //         final String filePath =
//         //             '${testDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
//         //         return SingleCaptureRequest(filePath, sensors.first);
//         //       }
//         //       // Separate pictures taken with front and back camera
//         //       return MultipleCaptureRequest(
//         //         {
//         //           for (final sensor in sensors)
//         //             sensor:
//         //                 '${testDir.path}/${sensor.position == SensorPosition.front ? 'front_' : "back_"}${DateTime.now().millisecondsSinceEpoch}.jpg',
//         //         },
//         //       );
//         //     },
//         //     videoOptions: VideoOptions(
//         //       enableAudio: true,
//         //       ios: CupertinoVideoOptions(
//         //         fps: 10,
//         //       ),
//         //       android: AndroidVideoOptions(
//         //         bitrate: 6000000,
//         //         fallbackStrategy: QualityFallbackStrategy.lower,
//         //       ),
//         //     ),
//         //     exifPreferences: ExifPreferences(saveGPSLocation: true),
//         //   ),
//         //   sensorConfig: SensorConfig.single(
//         //     sensor: Sensor.position(SensorPosition.back),
//         //     flashMode: FlashMode.auto,
//         //     aspectRatio: CameraAspectRatios.ratio_4_3,
//         //     zoom: 0.0,
//         //   ),
//         //   enablePhysicalButton: true,
//         //   // filter: AwesomeFilter.AddictiveRed,
//         //   previewAlignment: Alignment.center,
//         //   previewFit: CameraPreviewFit.contain,
//         //   onMediaTap: (mediaCapture) {
//         //     mediaCapture.captureRequest.when(
//         //       single: (single) {
//         //         Logger.d('single: ${single.file?.path}');
//         //         launchUrl(Uri.parse(single.file?.path ?? ''));
//         //       },
//         //       multiple: (multiple) {
//         //         multiple.fileBySensor.forEach((key, value) {
//         //           Logger.d('multiple file taken: $key ${value?.path}');
//         //           launchUrl(Uri.parse(value?.path ?? '')); // Use launchUrl instead of open
//         //         });
//         //       },
//         //     );
//         //   },
//         //   availableFilters: awesomePresetFiltersList,
//         //   previewDecoratorBuilder: (cameraState, preview) {
//         //     XFile? currentImage;

//         //     // Add a method to capture the image when needed
//         //     void captureCurrentImage() async {
//         //       // Assuming you have a method to capture the image
//         //       currentImage = await cameraState.captureImage(); // Replace with your actual capture method
//         //     }

//         //     // Get coordinates for AR overlays
//         //     return FutureBuilder<List<List<Offset>>>(
//         //       future: currentImage != null ? getGreenSquareCoordinates(currentImage!) : Future.value([]), // Pass the current image
//         //       builder: (context, snapshot) {
//         //         if (snapshot.connectionState == ConnectionState.waiting) {
//         //           return Center(child: CircularProgressIndicator()); // Loading indicator
//         //         } else if (snapshot.hasError) {
//         //           return Center(child: Text('Error: ${snapshot.error}')); // Error handling
//         //         } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//         //           return Center(child: Text('No coordinates found')); // No data handling
//         //         }

//         //         final list_of_coordinates = snapshot.data!; // Get the list of coordinates

//         //         return Stack(
//         //           children: [
//         //             Container(child: preview as Widget), // The camera preview
//         //             CustomPaint(
//         //               painter: GreenSquarePainter(list_of_coordinates), // Pass the list of coordinates
//         //               child: Container(),
//         //             ),
//         //           ],
//         //         );
//         //       },
//         //     );
//         //   },
//         // ),
//       // ),
//     );
//   }
// }

// // Custom painter for drawing green squares
// class GreenSquarePainter extends CustomPainter {
//   final List<List<Offset>> coordinates; // Change to List<List<Offset>>

//   GreenSquarePainter(this.coordinates);

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.green
//       ..style = PaintingStyle.fill;

//     for (var coordinatePair in coordinates) {
//       if (coordinatePair.length == 2) { // Ensure there are exactly two offsets
//         canvas.drawRect(
//           Rect.fromCenter(center: coordinatePair[0], width: coordinatePair[1].dx, height: coordinatePair[1].dy),
//           paint,
//         );
//       }
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) {
//     return true; // Repaint whenever the coordinates change
//   }
// }

// // Function to handle the captured image
// void handleCapturedImage(String imagePath) {
//   // Implement your logic to handle the captured image
//   Logger.d('Captured image path: $imagePath');
// }

// CameraAwesomeBuilder.custom(
//   saveConfig = SaveConfig.photo(),
//   builder = (cameraState, previewSize, previewRect) {
//     // Custom function to overlay AR on the camera preview
//     Widget arOverlay = buildAROverlay(); // Your AR overlay widget

//     return Stack(
//       children: [
//         // Camera preview
//         CameraPreview(cameraState),
//         // AR overlay
//         Positioned.fill(child: arOverlay),
//         // Capture button
//         Positioned(
//           bottom: 20,
//           left: (previewRect.width / 2) - 30,
//           child: ElevatedButton(
//             onPressed: () async {
//               // Capture the image and pass it to the custom function
//               final mediaCapture = await cameraState.takePicture();
//               handleCapturedImage(mediaCapture.filePath); // Your function to handle the image
//             },
//             child: Text('Capture'),
//           ),
//         ),
//       ],
//     );
//   },
// );

// // Function to build your AR overlay
// Widget buildAROverlay() {
//   // Implement your AR overlay logic here
//   return Container(
//     color: Colors.transparent, // Example overlay
//     child: Center(child: Text('AR Overlay', style: TextStyle(color: Colors.white))),
//   );
// }

// // Function to handle the captured image
// void handleCapturedImage(String imagePath) {
//   // Implement your logic to handle the captured image
//   Logger.d('Captured image path: $imagePath');
// }
