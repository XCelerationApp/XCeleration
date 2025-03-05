import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// This is a utility script to generate splash screen assets

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Generate icon_splash.png - the XC logo in a white circle
  final iconSplashWidget = Container(
    width: 300,
    height: 300,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 15,
          spreadRadius: 1,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFFF5722),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'XC',
            style: TextStyle(
              fontSize: 100,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -2,
            ),
          ),
        ),
      ),
    ),
  );
  
  // Generate branding.png - the app name and subtitle
  final brandingWidget = Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'XCelerate',
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1.2,
          shadows: [
            Shadow(
              blurRadius: 3.0,
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Race Timer',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: Colors.white.withOpacity(0.9),
        ),
      ),
    ],
  );
  
  // Save the image files
  await saveWidgetAsImage(iconSplashWidget, 'icon_splash.png', 400, 400);
  await saveWidgetAsImage(brandingWidget, 'branding.png', 300, 100);
  
  print('Splash screen assets generated successfully!');
  exit(0);
}

Future<void> saveWidgetAsImage(Widget widget, String fileName, double width, double height) async {
  final repaintBoundary = RepaintBoundary(
    child: Container(
      width: width,
      height: height,
      color: Colors.transparent,
      child: Center(child: widget),
    ),
  );
  
  final pipelineOwner = PipelineOwner();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
    container: RenderView(
      configuration: ViewConfiguration(
        size: Size(width, height),
        devicePixelRatio: 1.0,
      ),
      window: ui.window,
    ),
    child: repaintBoundary,
  ).attachToRenderTree(buildOwner);
  
  buildOwner.buildScope(rootElement);
  buildOwner.finalizeTree();
  
  pipelineOwner.flushLayout();
  pipelineOwner.flushCompositingBits();
  pipelineOwner.flushPaint();
  
  final renderObject = repaintBoundary.debugGetRenderObject() as RenderRepaintBoundary;
  final image = await renderObject.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final buffer = byteData!.buffer.asUint8List();
  
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(buffer);
  
  print('Saved $fileName to ${file.path}');
}
