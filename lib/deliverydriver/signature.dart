// ignore_for_file: sort_child_properties_last, prefer_const_constructors, prefer_const_declarations, no_leading_underscores_for_local_identifiers, prefer_interpolation_to_compose_strings, use_build_context_synchronously

import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sura_driver/mainscreen.dart';
// import 'package:signature/take_camera_image.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import '../network/api.dart';
// import 'online.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:sura_driver/color/color.dart';

void main() {
  HttpOverrides.global = MyHttpOverrides();
}

///Renders the SignaturePad widget.

class SignaturePadApp extends StatefulWidget {
  @override
  int id;
  String name;

  SignaturePadApp({
    required this.id,
    required this.name,
  });
  State<SignaturePadApp> createState() => _SignaturePadAppState();
}

class _SignaturePadAppState extends State<SignaturePadApp> {
  late final Uint8List signature1;
  late File signature;
  String? rate;
  bool isLoading = false;
  final GlobalKey<SfSignaturePadState> signatureGlobalKey = GlobalKey();
  bool isLoad = false;
  showSnack(String message, context, undo) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        action: undo != null
            ? SnackBarAction(
                label: '',
                onPressed: undo,
              )
            : null,
      ));
  @override
  void initState() {
    super.initState();
  }

  void _handleClearButtonPressed() {
    signatureGlobalKey.currentState!.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Гарын үсэг зурах'),
        actions: [
          // IconButton(
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => MyHomePage(),
          //       ),
          //     );
          //   },
          //   icon: Icon(Icons.arrow_forward),
          // ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Row(
        children: [
          Padding(
            padding: EdgeInsets.all(10),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.8,
              width: MediaQuery.of(context).size.width * 0.75,
              child: SfSignaturePad(
                  key: signatureGlobalKey,
                  backgroundColor: Colors.white,
                  strokeColor: Colors.black,
                  minimumStrokeWidth: 5.0,
                  maximumStrokeWidth: 10.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
            ),
          ),
          SizedBox(height: 10),
          Column(
            children: <Widget>[
              TextButton(
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: Text('Хадгалах'),
                  ),
                  onPressed: () {
                    log("press :");

                    _handleSaveButtonPressed();
                  }),
              TextButton(
                child: RotatedBox(
                  quarterTurns: -1,
                  child: Text('Цэвэрлэх'),
                ),
                onPressed: _handleClearButtonPressed,
              )
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          )
        ],
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
      ),
    );
  }

  void _handleSaveButtonPressed() async {
    final data =
        await signatureGlobalKey.currentState!.toImage(pixelRatio: 3.0);
    final bytes = await data.toByteData(format: ui.ImageByteFormat.png);
    late final _ratingController;
    late double _rating;

    double _userRating = 3.0;
    int _ratingBarMode = 1;
    double _initialRating = 2.0;
    bool _isRTLMode = false;
    bool _isVertical = false;
    IconData? _selectedIcon;

    log("==========> ${bytes}");
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                children: [
                  SizedBox(
                    height: 30,
                  ),
                  Container(
                    width: 200,
                    color: Colors.grey[300],
                    child: Image.memory(bytes!.buffer.asUint8List()),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Container(
                    child: Text(
                        'Та бидний ажилд туслан үнэлгээ өгнө үү. \n баярлалаа'),
                  ),
                  Center(
                    child: RatingBar(
                      initialRating: 1.0,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemSize: 48.0,
                      ratingWidget: RatingWidget(
                        full: Icon(Icons.star, color: Colors.amber),
                        half: Icon(Icons.star_half, color: Colors.amber),
                        empty: Icon(Icons.star_border, color: Colors.amber),
                      ),
                      onRatingUpdate: (rating) {
                        print(rating);
                        setState(() {
                          rate = rating.toString();
                        });
                      },
                    ),
                  ),
                  ElevatedButton(
                      onPressed: () async {
                        postImage();
                      },
                      child: Text("Хадгалах"))
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future postImage() async {
    final data =
        await signatureGlobalKey.currentState!.toImage(pixelRatio: 3.0);

    ui.Image image =
        await signatureGlobalKey.currentState!.toImage(pixelRatio: 3.0);
    final bytes = await data.toByteData(format: ui.ImageByteFormat.png);

    final Uint8List imageBytes =
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);

    final String path = (await getApplicationDocumentsDirectory()).path;
    final String finalName = '$path/Output.png';
    final File file = File(finalName);
    log('===== ${file.path}');
    await file.writeAsBytes(imageBytes, flush: true);

    var request =
        http.MultipartRequest('POST', Uri.parse(Url.url + '/api/v1/sign'));
    request.fields['phone'] = widget.id.toString();
    print(rate.toString() + "sasa");
    request.fields['rating'] = rate.toString();

    request.files.add(http.MultipartFile.fromBytes(
        "image", File(file.path).readAsBytesSync(),
        filename: file.path));

    var res = await request.send();

    if (res.statusCode == 200) {
      log("========> ok");
      print(widget.name.toString() + "qqqsss");
      Navigator.push(context,
          new MaterialPageRoute(builder: (context) => MainScreen(id: 1)));
      return ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("success")),
      );
    } else {
      log("=======> Error");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("success")));
    }

    print("Image Data $res ${await res.stream.bytesToString()}");

    setState(() {
      isLoading = true;
    });

    setState(() {
      isLoading = false;
    });
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
