import 'dart:developer';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';



class ImagePreviewPage extends StatelessWidget {
  
  final XFile imagePath;

  const ImagePreviewPage({Key? key, required this.imagePath, }) : super(key: key);

  // function to save image to gallery

  Future<bool> saveImage(XFile image)async{
    Directory? directory;
    log('saveFile: $image');
    
    try{
      if(Platform.isAndroid){
          directory = await getExternalStorageDirectory();
          log("directory: $directory");
          String newPath = "";
          List<String> folders = directory!.path.split('/');
          for(int x=1; x<folders.length; x++){
            String folder = folders[x];
            if(folder != "Android"){
              newPath += "/$folder";
            }else{
              break;
            }}
            newPath = newPath + "/detected_images";
            directory = Directory(newPath);
            log("newPath: $newPath");
      }else{
            if (await Permission.photos.request().isGranted) {
              directory = await getTemporaryDirectory();

            } else {
              return false;
            }
      }
      if(!await directory.exists()){
        await directory.create(recursive: true);
      }
      try {
      String? path = await FilePicker.platform.saveFile(
        fileName: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        bytes: await image.readAsBytes(),
      );
      if (path != null) {
        log('Image saved to: $path');
      } else {
        log('Error saving image');
      }
    } catch (e) {
      log("Error saving image: $e");
    }
    
      if(await directory.exists()){
        log("here");
        File newImage = File('${directory.path}/hey.png');
        await newImage.writeAsBytes(await image.readAsBytes());
        if (Platform.isIOS){
          ImageGallerySaver.saveImage(await image.readAsBytes(), isReturnImagePathOfIOS: true);
        }
      } else {
        log('Could not get path');
      }

    }catch(e){
      log('Error saving file: ${e.runtimeType}: ${e.toString()}');
      return false;
    }
    return false;
  }


  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Captured Image'),
    ),
    body: Image.file(File(imagePath.path)),
    floatingActionButton: FloatingActionButton(
      onPressed: () {
        saveImage(imagePath);
      },
      child: Icon(Icons.save),
    ),
  );
}}
