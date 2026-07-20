import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app_text.dart';
// import 'package:buuhia/screen/detail.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'package:http/http.dart' as http;
import 'package:sura_driver/color/color.dart';

import 'package:sura_driver/network/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screen/login.dart';

class Album {
  final String shop;
  final String phone;
  final String address;
  final String status;
  final String comment;

  final int id;
  const Album({
    required this.id,
    required this.shop,
    required this.phone,
    required this.address,
    required this.status,
    required this.comment,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'],
      shop: json['shop'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      status: json['status'] ?? '',
      comment: json['comment'] ?? '',
    );
  }
}

class Doneorder extends StatefulWidget {
  int id;
  String searchString = "";
  String name;
  Doneorder({required this.name, required this.id});
  @override
  _DoneorderState createState() => _DoneorderState();
}

class Debouncer {
  int? milliseconds;
  VoidCallback? action;
  Timer? timer;

  run(VoidCallback action) {
    if (null != timer) {
      timer!.cancel();
    }
    timer = Timer(
      Duration(milliseconds: Duration.millisecondsPerSecond),
      action,
    );
  }
}

class _DoneorderState extends State<Doneorder>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _debouncer = Debouncer();
  final RefreshController _refreshController = RefreshController();
  bool isCameraOn = false;
  final _formKey = GlobalKey<FormState>();
  List<int> _selected_box = [];
  List<Album> ulist = [];
  List<Album> userLists = [];
  bool isChecked = false;
  Color getColor(Set<MaterialState> states) {
    const Set<MaterialState> interactiveStates = <MaterialState>{
      MaterialState.pressed,
      MaterialState.hovered,
      MaterialState.focused,
    };
    if (states.any(interactiveStates.contains)) {
      return Colors.blue;
    }
    return Color(0xFF6f42c1);
  }

  var email;
  var password;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool isLoading = true;
  late Future<List<Album>> futureAlbum;

  String _value = "1";
  String id = "2";
  String _selectedText = "4";

  List<String> _list = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"];

  Future<List<Album>> fetchAlbum() async {
    final response =
        await http.get(Uri.parse(Url.url + '/api/v1/doneorder/' + widget.name));
    print(Url.url + '/api/v1/order/' + widget.name + "ssss");
    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      print(response.body);
      List list = jsonDecode(response.body)['data'];
      return (list.map((e) => Album.fromJson(e)).toList()) as List<Album>;
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      print(Url.url.toString());
      throw Exception('Failed to load album');
    }
  }

  static List<Album> parseAgents(String responseBody) {
    final parsed = json.decode(responseBody).cast<Map<String, dynamic>>();
    return parsed.map<Album>((json) => Album.fromJson(json)).toList();
  }

  late String _now;
  late Timer _everySecond;
  @override
  void initState() {
    super.initState();
    futureAlbum = fetchAlbum();
    fetchAlbum().then((subjectFromServer) {
      setState(() {
        ulist = subjectFromServer;
        userLists = ulist;
      });
    });
  }

  showAlertDialogMore(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierLabel: "Label",
      barrierDismissible: true,
      // barrierColor: Colors.white,
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              return Container(
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: 50,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      elevation: 0,
                      itemHeight: 50.0,
                      iconSize: 30.0,
                      icon: Container(),
                      value: _value,
                      items: _list.map((String item) {
                        return DropdownMenuItem(
                            value: item,
                            child: Container(
                              alignment: Alignment.center,
                              height: 30,
                              child: Text(item),
                            ));
                      }).toList(),
                      onChanged: (newValue) {
                        for (var i = 0; i < _selected_box.length; i++) {
                          _selectedText = newValue!;

                          setState(() {
                            _value = newValue;
                            update(_selected_box[i], _value);
                          });

                          print(_selected_box[i]);
                        }
                      },
                    ),
                  ));
            }));
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position:
              Tween(begin: Offset(0, 1), end: Offset(0, 0)).animate(anim1),
          child: child,
        );
      },
    );
  }

  // String name;

  _showMsg(msg) {
    final snackBar = SnackBar(
      content: Text(msg),
      action: SnackBarAction(
        label: 'Close',
        onPressed: () {
          // Some code to undo the change!
        },
      ),
    );
  }

  void logError(String code, String message) {
    if (message != null) {
      print('Error: $code\nError Message: $message');
    } else {
      print('Error: $code');
    }
  }

  _loadUserData() async {
    SharedPreferences localStorage = await SharedPreferences.getInstance();
    // var user = jsonDecode(localStorage.getString('user'));
    //
    // if (user != null) {
    //   setState(() {
    //     // name = user['fname'];
    //   });
    // }
  }

  @override
  Widget build(BuildContext context) {
    double totalHeight = MediaQuery.of(context).size.height;
    double totalWidth = MediaQuery.of(context).size.width;

    return Scaffold(
        appBar: AppBar(
          titleSpacing: 0.0,
          backgroundColor: Colors.white,
          bottomOpacity: 0.0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Row(
                    children: [
                      Image.asset(
                        'assets/user.png',
                        width: 50,
                      ),
                      Padding(
                          padding: EdgeInsets.only(left: 20),
                          child: Text(
                            widget.name,
                            style: TextStyle(color: Colors.black),
                          )),
                    ],
                  )
                ],
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(13),
            ),
          ),
          elevation: 0.0,
          automaticallyImplyLeading: false,
          centerTitle: true,
          actions: <Widget>[
            Container(
                width: totalWidth * 0.2,
                child: Row(
                  children: <Widget>[
                    Expanded(
                        child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.push(
                                context,
                                new MaterialPageRoute(
                                    builder: (context) => Login()));
                          },
                          child: Padding(
                            padding: EdgeInsets.only(top: 0),
                            child: Image.asset(
                              'assets/logout.png',
                              width: 25,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: 0),
                          child: Image.asset(
                            'assets/bell.png',
                            width: 30,
                          ),
                        ),
                      ],
                    )),
                  ],
                ))
          ],
        ),
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
            child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(top: 10, left: 0),
              child: SizedBox(
                height: 60,
                width: totalWidth * 0.94,
                child: TextField(
                  style: TextStyle(color: Color(0xFF000000)),
                  cursorColor: Color(0xFF9b9b9b),
                  keyboardType: TextInputType.text,
                  onChanged: (string) {
                    _debouncer.run(() {
                      setState(() {
                        // userLists = ulist
                        //     .where(
                        //       (u) => (u.phone.toLowerCase().contains(
                        //     string.toLowerCase(),
                        //   )),
                        // )
                        //     .toList();
                      });
                    });
                  },
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(10),
                      child: Container(
                        width: 30,
                        height: 30,
                        child: Image.asset(
                          'assets/search.png',
                        ),
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    hintText: "Утасны дугаараар хайна уу",
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    hintStyle: TextStyle(
                        color: Color(0xFF9b9b9b),
                        fontSize: 15,
                        fontWeight: FontWeight.normal),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  FutureBuilder<List<Album>>(
                    future: futureAlbum,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Container(
                          height: totalHeight * 0.65,
                          child: SmartRefresher(
                            enablePullDown: true,
                            header: WaterDropHeader(),
                            controller: _refreshController,
                            onRefresh: () async {
                              await Future.delayed(Duration(seconds: 1));
                              _refreshController.refreshCompleted();
                              setState(() {
                                futureAlbum = fetchAlbum();
                              });
                            },
                            onLoading: fetchAlbum,
                            child: ListView.builder(
                              itemCount: userLists.length,
                              itemBuilder: (context, index) {
                                return Column(
                                  children: [
                                    Container(
                                      margin: EdgeInsets.only(top: 10),
                                      child: Container(
                                        width: totalWidth * 1,
                                        child: Row(
                                          children: <Widget>[
                                            SizedBox(
                                              width: 5,
                                            ),
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  Container(
                                                    margin: EdgeInsets.only(
                                                        left: 0, top: 2),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: <Widget>[
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                userLists[index]
                                                                    .shop,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color: Colors
                                                                        .black),
                                                              ),
                                                            ),
                                                            Container(
                                                                margin: EdgeInsets
                                                                    .only(
                                                                        right:
                                                                            10),
                                                                child: Text(
                                                                  userLists[index]
                                                                          .phone ??
                                                                      "",
                                                                  style: appText(
                                                                      fontSize:
                                                                          13,
                                                                      color: Colors
                                                                          .black),
                                                                )),
                                                          ],
                                                        ),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                                child:
                                                                    Container(
                                                              height: 20,
                                                              width: 20,
                                                              child: Text(
                                                                userLists[index]
                                                                    .comment
                                                                    .toString(),
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color: Colors
                                                                        .grey),
                                                              ),
                                                            )),
                                                            if (userLists[index]
                                                                    .status ==
                                                                '3')
                                                              Container(
                                                                  margin: EdgeInsets
                                                                      .only(
                                                                          left:
                                                                              10,
                                                                          right:
                                                                              10),
                                                                  child: Text(
                                                                    "Авсан",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13,
                                                                        color: Colors
                                                                            .grey),
                                                                  ))
                                                            else
                                                              Container(
                                                                margin: EdgeInsets
                                                                    .only(
                                                                        left:
                                                                            10,
                                                                        right:
                                                                            10),
                                                                child: Text(
                                                                  "Дууссан",
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      color: Colors
                                                                          .grey),
                                                                ),
                                                              )
                                                          ],
                                                        ),
                                                        Container(
                                                          margin:
                                                              EdgeInsets.only(
                                                                  left: 0),
                                                          child: Text(
                                                            userLists[index]
                                                                    .address ??
                                                                '',
                                                            // 'Хүргэх хаяг: БЗД, 14-р хороо, Энхтайваны өргөн чөлө',
                                                            style: TextStyle(
                                                                color: AppColors
                                                                    .primaryColor,
                                                                fontSize: 14),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: EdgeInsets.only(top: 5),
                                      height: 1,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom:
                                              BorderSide(color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Text('${snapshot.error}');
                      }

                      // By default, show a loading spinner.
                      return const CircularProgressIndicator();
                    },
                  ),
                ],
              ),
            )
          ],
        )));
  }

  Future<void> sendPost(String value, ids) async {
    // int status = int.parse(value.split(" ").last);
    String status = value.toString();
    String id = ids.toString();
    Map<String, dynamic> data = {
      "id": id.toString(),
      "ordering": status.toString(),
    };
    print(ids.toString());
    print(status.toString());

    final http.Response response = await http
        .post(Uri.parse('http://103.50.206.45/api/v1/ordering'), body: data);
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseMap = json.decode(response.body);
      print(responseMap);
      Navigator.pop(context);
      SharedPreferences localStorage = await SharedPreferences.getInstance();
      var username = localStorage.getString('username');
      // Navigator.push(
      //     context,
      //     new MaterialPageRoute(
      //         builder: (context) => MainScreen(
      //           username: username,
      //         ))).then((value) => WidgetsBinding.instance
      //     ?.addPostFrameCallback((_) => setState(() {})));
    }
  }

  Future<void> update(int value, ids) async {
    // int status = int.parse(value.split(" ").last);

    String status = value.toString();
    String id = ids.toString();
    print(status);
    print(id);

    Map<String, dynamic> data = {
      "id": status.toString(),
      "ordering": id.toString(),
    };
    print(ids.toString());
    print(status.toString());
    SharedPreferences localStorage = await SharedPreferences.getInstance();

    var username = localStorage.getString('username');

    final http.Response response = await http
        .post(Uri.parse('http://103.50.206.45/api/v1/ordering'), body: data);
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseMap = json.decode(response.body);
      // Navigator.push(
      //     context,
      //     new MaterialPageRoute(
      //         builder: (context) => MainScreen(
      //           username: username,
      //         ))).then((value) => WidgetsBinding.instance
      //     ?.addPostFrameCallback((_) => setState(() {})));
      print(responseMap);
    }
  }

  Future<void> updateOrder(String value, ids) async {
    // int status = int.parse(value.split(" ").last);
    String status = value.toString();
    String id = ids.toString();
    Map<String, dynamic> data = {
      "id": id.toString(),
      "ordering": status.toString(),
    };
    print(ids.toString());
    print(status.toString());

    final http.Response response = await http
        .post(Uri.parse('http://103.50.206.45/api/v1/ordering'), body: data);
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseMap = json.decode(response.body);
      print(responseMap);
      Navigator.pop(context);
    }
  }

  void logout() async {
    // var res = await Network().getData('/logout');
    // var body = json.decode(res.body);
    // if (body['success']) {
    //   SharedPreferences localStorage = await SharedPreferences.getInstance();
    //   localStorage.remove('user');
    //   localStorage.remove('token');
    //   Navigator.push(context, MaterialPageRoute(builder: (context) => Login()));
    // }
  }
}
