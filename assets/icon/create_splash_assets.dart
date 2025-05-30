import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// This is a utility script to generate splash screen assets

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Generate icon_splash.png - the XC logo in a white circle
  final logoSplash = Container(
    width: 192,
    height: 192,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
    ),
    child: Center(
      child: Image.asset(
        'assets/icon/xclogo.png',
        width: 150,
        height: 150,
      ),
    ),
  );

  await saveWidgetAsImage(logoSplash, 'icon_splash.png', 512, 512);

  // Generate iOS splash screens for various device sizes
  final iosSplash = Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
      ),
    ),
    child: Center(
      child: Container(
        width: 192,
        height: 192,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Center(
          child: Image.asset(
            'assets/icon/xclogo.png',
            width: 150,
            height: 150,
          ),
        ),
      ),
    ),
  );

  // iPhone (Portrait)
  await saveWidgetAsImage(iosSplash, 'splash_ios_portrait.png', 1125, 2436);

  // iPhone (Landscape)
  await saveWidgetAsImage(iosSplash, 'splash_ios_landscape.png', 2436, 1125);

  // iPad (Portrait)
  await saveWidgetAsImage(iosSplash, 'splash_ipad_portrait.png', 1536, 2048);

  // iPad (Landscape)
  await saveWidgetAsImage(iosSplash, 'splash_ipad_landscape.png', 2048, 1536);

  // Android splash screens
  final androidSplash = Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
      ),
    ),
    child: Center(
      child: Container(
        width: 192,
        height: 192,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Center(
          child: Image.asset(
            'assets/icon/xclogo.png',
            width: 150,
            height: 150,
          ),
        ),
      ),
    ),
  );

  // Android (Portrait)
  await saveWidgetAsImage(
      androidSplash, 'splash_android_portrait.png', 1080, 1920);

  // Android (Landscape)
  await saveWidgetAsImage(
      androidSplash, 'splash_android_landscape.png', 1920, 1080);

  Logger.d('Splash screen assets generated successfully!');
  exit(0);
}

Future<void> saveWidgetAsImage(
    Widget widget, String fileName, double width, double height) async {
  // Create a RepaintBoundary to capture the widget
  final boundary = RepaintBoundary(
    child: Container(
      width: width,
      height: height,
      color: Colors.transparent,
      child: Center(child: widget),
    ),
  );

  // Create a RenderObject
  final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
    container: RenderView(
      view: ui.PlatformDispatcher.instance.views.first,
      configuration: ViewConfiguration(),
    ),
    child: boundary,
  ).attachToRenderTree(BuildOwner(focusManager: FocusManager()));

  // Layout the widget
  final buildOwner = BuildOwner(focusManager: FocusManager());
  buildOwner.buildScope(rootElement);
  buildOwner.finalizeTree();

  // Find the RenderRepaintBoundary
  RenderRepaintBoundary? renderRepaintBoundary;

  // Use a direct approach to find the boundary
  void visitor(RenderObject object) {
    if (object is RenderRepaintBoundary) {
      renderRepaintBoundary = object;
      return;
    }
    object.visitChildren(visitor);
  }

  final renderView = rootElement.renderObject as RenderView;
  renderView.visitChildren(visitor);

  // Ensure we found the boundary
  if (renderRepaintBoundary == null) {
    throw Exception('Could not find RenderRepaintBoundary in the render tree');
  }

  // Capture to image using the found boundary
  final image = await renderRepaintBoundary!.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final buffer = byteData!.buffer.asUint8List();

  // Save to file
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(buffer);

  Logger.d('Saved $fileName to ${file.path}');
}
