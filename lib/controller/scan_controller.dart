import 'dart:developer';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../views/ImagePreviewPage.dart';

class ScanController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    initCamera();
    initFlite();
  }

  @override
  void dispose() {
    super.dispose();
    cameraController.dispose();
  }

  late CameraController cameraController;
  late List<CameraDescription> cameras;

  var isCameraInitialized = false.obs;
  var camCount = 0;
  var x = 0.0.obs;
  var y = 0.0.obs;
  var w = 0.0.obs;
  var h = 0.0.obs;
  var label = "".obs;

  // Define maximum zoom level (adjust as needed)
  final double maxZoomLevel = 2.0;

  Future<void> initCamera() async {
    var cameraPermission = await Permission.camera.request();
    if (cameraPermission.isGranted) {
      cameras = await availableCameras();
      cameraController = CameraController(
        cameras[0],
        ResolutionPreset.max,
      );

      try {
        await cameraController.initialize().then((_) {
          cameraController.startImageStream((image) {
            camCount++;
            if (camCount % 50 == 0) {
              camCount = 0;
              objectDetector(image);
            }
            update();
          });
        });
      } catch (e) {
        log('Error initializing camera: $e');
      }

      isCameraInitialized.value = true;
      update();
    } else {
      log('Permission Denied');
      initCamera();
    }
  }

  Future<void> initFlite() async {
    await Tflite.loadModel(
      model: "assets/ssd_mobilenet.tflite",
      labels: "assets/ssd_mobilenet.txt",
      numThreads: 1,
      isAsset: true,
      useGpuDelegate: false,
    ).then((_) => log("Model Loaded")).catchError((e) => log("Error Loading Model: $e"));
  }

  Future<void> objectDetector(CameraImage image) async {
    var now = DateTime.now();
    var previousFrameTime;
    if (previousFrameTime != null &&
        now.difference(previousFrameTime) < Duration(milliseconds: 250)) {
      return; // Skip inference if less than 250ms since last one
    }
    previousFrameTime = now;
    try {
      var detector = await Tflite.detectObjectOnFrame(
        bytesList: image.planes.map((plane) => plane.bytes).toList(),
        model: "SSDMobileNet",
        imageHeight: image.height,
        imageWidth: image.width,
        imageMean: 127.5,
        imageStd: 127.5,
        threshold: 0.4,
        numResultsPerClass: 1,
      );

      if (detector != null) {
        label.value = detector.first['detectedClass'];
        h.value = detector.first['rect']['h'];
        w.value = detector.first['rect']['w'];
        x.value = detector.first['rect']['x'];
        y.value = detector.first['rect']['y'];
        

        // Zoom in based on the height of the detected object
        double targetZoomLevel = MediaQuery.of(Get.context!).size.height / (h.value * 2);
        if (targetZoomLevel > maxZoomLevel) {
          targetZoomLevel = maxZoomLevel;
          captureImage();
        }
        await cameraController.setZoomLevel(targetZoomLevel);
      }
    } catch (e) {
      if (e is PlatformException && e.message?.contains('Interpreter busy') == true) {
        log('Inference skipped (interpreter busy)');
      } else {}
    }
  }

  void captureImage() async {
    if (cameraController.value.isRecordingVideo) {
      // Stop recording if needed (optional)
      return;
    }

    try {
      final XFile image = await cameraController.takePicture();
      stopCameraStream(); // Stop camera stream before navigating away
      Get.to(() => ImagePreviewPage(
            imagePath: image,
            // x: x.value.toInt(),
            // y: y.value.toInt(),
            // w: w.value.toInt(),
            // h: h.value.toInt(),
          ));
    } catch (e) {
      log('Error capturing image: $e');
    }
  }

  void stopCameraStream() {
    if (cameraController != null) {
      cameraController.stopImageStream();
    }
  }
}
