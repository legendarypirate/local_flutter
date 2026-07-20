import 'dart:convert';
import 'dart:math';
import '../app_text.dart';

import 'package:sura_driver/customerscreen.dart';
import 'package:sura_driver/network/api.dart';
import 'package:flutter/material.dart';
import 'package:sura_driver/screen/orderdrivermain.dart';
// import 'package:sura_driver/mainscreen.dart';
// import 'package:sura_driver/screen/mainforavdag.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:http/http.dart' as http;

import '../color/color.dart';
import '../mainscreen.dart';
import '../network/api.dart';

class Login extends StatefulWidget {
  // LoginScreen({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

Future<void> checkrememberme() async {
  SharedPreferences localStorage = await SharedPreferences.getInstance();
  var type = localStorage.getString('type');
}

class _LoginState extends State<Login> {
  bool _passwordVisible = false;
  bool _isDriver = true;

  @override
  void initState() {
    _passwordVisible = false;
    _loadRememberMeStatus();
  }

  Future<void> _loadRememberMeStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('rememberMe') ?? false;
      if (_rememberMe) {
        namecont.text = prefs.getString('username') ?? '';
        passcont.text = prefs.getString('password') ?? '';
      }
    });
  }

  Future<void> _saveRememberMeStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', _rememberMe);
    if (_rememberMe) {
      await prefs.setString('username', namecont.text);
      await prefs.setString('password', passcont.text);
    } else {
      await prefs.remove('username');
      await prefs.remove('password');
    }
  }

  bool _rememberMe = false;
  Color getColor(Set<MaterialState> states) {
    const Set<MaterialState> interactiveStates = <MaterialState>{
      MaterialState.pressed,
      MaterialState.hovered,
      MaterialState.focused,
    };
    if (states.any(interactiveStates.contains)) {
      return Color(0xFF0035ad);
    }
    return Color(0xFF0035ad);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: _getBody(),
    );
  }

  TextEditingController passcont = TextEditingController();
  TextEditingController namecont = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  Widget _getBody() {
    double totalHeight = MediaQuery.of(context).size.height;
    double totalWidth = MediaQuery.of(context).size.width;
    bool checkedBox = false;
    return Form(
      key: _formKey,
      child: Stack(
        children: <Widget>[
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 70,
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: totalWidth * 0.0,
                    top: totalHeight * 0.08,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12), // 👈 adjust radius
                    child: Image.asset(
                      'assets/locallogo.png',
                      width: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.only(
                      left: totalWidth * 0.0, top: totalHeight * 0),
                  child: Container(
                    // color: Color.fromARGB(50, 200, 50, 20),
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.only(
                              left: totalWidth * 0, top: totalHeight * 0.05),
                          child: SizedBox(
                            height: 50,
                            width: totalWidth * 0.9,
                            child: TextFormField(
                              controller: namecont,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter some text';
                                }
                                return null;
                              },
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                errorStyle: TextStyle(color: Colors.white),
                                hintText: 'Нэвтрэх нэр',
                                hintStyle: TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: Color(0xFFF8FAFB),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        BorderSide(color: Colors.white)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: AppColors.primaryColor)),
                              ),
                              cursorColor: Color(0xFF30C6CC),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                Padding(
                  padding: EdgeInsets.only(
                      left: totalWidth * 0.0, top: totalHeight * 0.0),
                  child: Container(
                    // color: Color.fromARGB(50, 200, 50, 20),
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.only(
                              left: totalWidth * 0, top: totalHeight * 0),
                          child: SizedBox(
                            height: 50,
                            width: totalWidth * 0.9,
                            child: TextFormField(
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter some text';
                                }
                                return null;
                              },
                              obscureText: !_passwordVisible,
                              controller: passcont,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                errorStyle: TextStyle(color: Colors.white),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    // Based on passwordVisible state choose the icon
                                    _passwordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Theme.of(context).primaryColorDark,
                                  ),
                                  onPressed: () {
                                    // Update the state i.e. toogle the state of passwordVisible variable
                                    setState(() {
                                      _passwordVisible = !_passwordVisible;
                                    });
                                  },
                                ),
                                hintText: 'Нууц үг',
                                hintStyle: TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: Color(0xFFF8FAFB),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        BorderSide(color: Colors.white)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: AppColors.primaryColor)),
                              ),
                              cursorColor: Color(0xFF30C6CC),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 30,
                ),
                Center(
                  child: Text(
                    'v2.0.0',
                    style: appText(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                      left: totalWidth * 0.0, top: totalHeight * 0.15),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        color: AppColors.primaryColor),
                    width: totalWidth * 0.9,
                    child: TextButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            try {
                              // Prepare your data as JSON
                              Map<String, dynamic> data = {
                                'username': namecont.text.trim(),
                                'password': passcont.text.trim(),
                              };

                              final uri = Uri.parse(Url.url + "/api/auth/login");

                              final response = await http.post(
                                uri,
                                headers: {"Content-Type": "application/json"},
                                body: jsonEncode(data),
                              );
                              print(jsonEncode(data));

                              if (response.statusCode == 200) {
                                final responseData = jsonDecode(response.body);

                                if (responseData['success'] == true) {
                                  int role = responseData['user']['role'] ?? -1;
                                  int userId = responseData['user']['id'] ?? -1;

                                  // Store login state immediately
                                  SharedPreferences prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('token', responseData['token']);
                                  await prefs.setString('username', namecont.text.trim());
                                  await prefs.setInt('role', role);
                                  await prefs.setInt('user_id', userId);
                                  await prefs.setBool('is_logged_in', true); // Add this flag

                                  // Check if user role matches the selected login type
                                  bool roleMatches = (_isDriver && role == 3) || (!_isDriver && role == 2);

                                  if (roleMatches) {
                                    // Navigate based on actual role, not the toggle state
                                    if (role == 3) {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MainScreen(id: userId),
                                        ),
                                            (route) => false, // Remove all previous routes
                                      );
                                    } else if (role == 2) {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => Customerscreen(id: userId),
                                        ),
                                            (route) => false, // Remove all previous routes
                                      );
                                    }
                                  } else {
                                    // Clear stored data if role doesn't match
                                    await prefs.remove('token');
                                    await prefs.remove('username');
                                    await prefs.remove('role');
                                    await prefs.remove('user_id');
                                    await prefs.remove('is_logged_in');

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            _isDriver
                                                ? 'This account is not a driver account'
                                                : 'This account is not a customer account'
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Invalid username or password')),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Server error: ${response.statusCode}')),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error occurred: $e')),
                              );
                            }
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          'НЭВТРЭХ',
                          style: appText(),
                        )),
                  ),
                ),

                SizedBox(height: 20),
                FlutterSwitch(
                  width: totalWidth * 0.9,
                  height: 35.0,
                  toggleSize: 30.0,
                  value: _isDriver,
                  borderRadius: 20.0,
                  padding: 4.0,
                  showOnOff: true,
                  activeText: "   Жолооч", // Add leading spaces
                  inactiveText: "Харилцагч" + "  ", // Add trailing spaces
                  activeTextColor: Colors.white,
                  inactiveTextColor: Colors.white,
                  // Lighter font weight
                  inactiveTextFontWeight: FontWeight.w400,
                  activeColor: Colors.green,
                  inactiveColor: Colors.blue,
                  onToggle: (val) {
                    setState(() {
                      _isDriver = val;
                    });
                  },
                )

                // InkWell(
                //     onTap: (){
                //       _launchURL();
                //     },
                //     child: Text('Privacy Policy',style: TextStyle(fontSize: 15,fontWeight: FontWeight.bold),)
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
