// // ignore_for_file: prefer_const_constructors, prefer_const_constructors_in_immutables, library_private_types_in_public_api, prefer_typing_uninitialized_variables
//
// import 'dart:convert';
// import 'dart:developer';
// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../mainscreen.dart';
//
// class MyHomePage extends StatefulWidget {
//   int id;
//   String searchString = "";
//
//   MyHomePage({required this.id});
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   File? _image;
//   late Uint8List imageFile;
//
//   bool isLoading = false;
//   var imageTeporary;
//   dynamic image1;
//
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Зураг авах"),
//         centerTitle: true,
//       ),
//       body: Column(
//         children: <Widget>[
//           Container(
//             height: 300,
//             width: 600,
//             child: _image != null
//                 ? Image.file(
//                     _image!,
//                     height: 100,
//                   )
//                 : null,
//           ),
//           ElevatedButton(
//             onPressed: () {
//               showDialog(
//                   context: context,
//                   builder: (context) {
//                     return AlertDialog(
//                       content: Column(
//                         crossAxisAlignment: CrossAxisAlignment.center,
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           ListTile(
//                             onTap: () {
//                               // getImageCamera();
//                               Navigator.pop(context);
//                             },
//                             title: Text("Camera"),
//                           ),
//                           ListTile(
//                             onTap: () {
//                               // getImageGallery();
//                               Navigator.pop(context);
//                             },
//                             title: Text("Gallery"),
//                           ),
//                         ],
//                       ),
//                     );
//                   });
//               // getImage();
//             },
//             child: Text("Зураг авах"),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               postImage();
//               log("press");
//             },
//             child: Text("Илгээх"),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future postImage() async {
//     setState(() {
//       isLoading = true;
//     });
//
//     var request = http.MultipartRequest(
//         'POST', Uri.parse('http://68.183.181.125/api/v1/postimage'));
//     request.fields['id'] = widget.id.toString();
//     request.files.add(http.MultipartFile.fromBytes(
//         "image", File(image1.path).readAsBytesSync(),
//         filename: image1.path));
//
//     var res = await request.send();
//     SharedPreferences localStorage = await SharedPreferences.getInstance();
//     var name = localStorage.getString('name') ?? '';
//     if (res.statusCode == 200) {
//       Navigator.push(
//           context,
//           new MaterialPageRoute(
//               builder: (context) => MainScreen(
//                 name: name,
//               ))).then((value) =>
//           WidgetsBinding.instance?.addPostFrameCallback((_) => setState(() {})));
//       return ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Амжилттай")),
//       );
//     }
//
//     print("Image Data $res ${await res.stream.bytesToString()}");
//
//     setState(() {
//       isLoading = false;
//     });
//   }
// }
