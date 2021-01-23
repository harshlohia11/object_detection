import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants.dart';
import 'dart:io';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Tflitehome(),
    );
  }
}

class Tflitehome extends StatefulWidget {
  @override
  _TflitehomeState createState() => _TflitehomeState();
}

class _TflitehomeState extends State<Tflitehome> {
  String _model = ssd;
  File _image;
  double _imgHeight;
  double _imgWidth;
  bool _busy = false;
  List _recognitions;

  @override
  void initState() {
    super.initState();
    _busy = true;
    loadModel().then((val) {
      setState(() {
        _busy = false;
      });
    });
  }

  loadModel() async {
    Tflite.close();
    try {
      String res;
      if (_model == yolo) {
        res = await Tflite.loadModel(
            model: "assets/tflite/yolov2_tiny.tflite",
            labels: "assets/tflite/yolov2_tiny.txt");
      } else {
        res = await Tflite.loadModel(
            model: "assets/tflite/ssd_mobilenet.tflite",
            labels: "assets/tflite/ssd_mobilenet.txt");
      }
      print(res);
    } on PlatformException {
      print("Failed to load model");
    }
  }

  pickImage() async {
    File image = await ImagePicker.pickImage(source: ImageSource.gallery);
    if (image == null)
      return;
    else {
      setState(() {
        _busy = true;
      });
      predictImage(image);
    }
  }

  pickImageCamera() async {
    File image = await ImagePicker.pickImage(source: ImageSource.camera);
    if (image == null)
      return;
    else {
      setState(() {
        _busy = true;
      });
      predictImage(image);
    }
  }

  showPicker(context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return SafeArea(
            child: Container(
              child: new Wrap(
                children: <Widget>[
                  new ListTile(
                      leading: new Icon(Icons.photo_library),
                      title: new Text('Photo Library'),
                      onTap: () {
                        pickImage();
                        Navigator.of(context).pop();
                      }),
                  new ListTile(
                    leading: new Icon(Icons.photo_camera),
                    title: new Text('Camera'),
                    onTap: () {
                      pickImageCamera();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          );
        });
  }

  predictImage(File image) async {
    if (image == null) return;
    if (_model == yolo) {
      await yolov2tiny(image);
    } else {
      await ssdmobilenet(image);
    }
    FileImage(image)
        .resolve(ImageConfiguration())
        .addListener((ImageStreamListener((ImageInfo _info, bool _) {
          setState(() {
            _imgWidth = _info.image.width.toDouble();
            _imgHeight = _info.image.height.toDouble();
          });
        })));
    setState(() {
      _image = image;
      _busy = false;
    });
  }

  yolov2tiny(File image) async {
    //int startTime = new DateTime.now().millisecondsSinceEpoch;
    var recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      model: "YOLO",
      threshold: 0.3,
      imageMean: 0.0,
      imageStd: 255.0,
      numResultsPerClass: 1,
    );
    setState(() {
      _recognitions = recognitions;
    });
    // int endTime = new DateTime.now().millisecondsSinceEpoch;
    // print("Inference took ${endTime - startTime}ms");
  }

  ssdmobilenet(File image) async {
    //int startTime = new DateTime.now().millisecondsSinceEpoch;
    var recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      numResultsPerClass: 1,
    );
    setState(() {
      _recognitions = recognitions;
    });
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imgHeight == null || _imgWidth == null) return [];

    double factorX = screen.width;
    double factorY = _imgHeight / _imgWidth * screen.width;
    Color blue = Color.fromRGBO(37, 213, 253, 1.0);
    return _recognitions.map((re) {
      return Positioned(
        left: re["rect"]["x"] * factorX,
        top: re["rect"]["y"] * factorY,
        width: re["rect"]["w"] * factorX,
        height: re["rect"]["h"] * factorY,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            border: Border.all(
              color: blue,
              width: 2,
            ),
          ),
          child: Text(
            "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = blue,
              color: Colors.white,
              fontSize: 12.0,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> stackChildren = [];
    stackChildren.add(Positioned(
      top: 0.0,
      left: 0.0,
      width: size.width,
      child: _image == null
          ? Center(
              child: Text("No image selected",
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0)),
            )
          : Image.file(_image),
    ));

    stackChildren.addAll(renderBoxes(size));
    if (_busy == true) {
      stackChildren.add(Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text("Object Detection")),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add_a_photo),
        tooltip: 'Pick a image',
        onPressed: () {
          showPicker(context);
        },
      ),
      body: Stack(
        children: stackChildren,
      ),
    );
  }
}
