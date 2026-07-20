import 'dart:io';

// import 'package:sura_driver/screen/mainforavdag.dart';
import 'package:flutter/material.dart';
// import 'package:sura_driver/screen/login.dart';
// import 'package:sura_driver/mainscreen.dart';
// import 'package:sura_driver/screen/settings.dart';
// import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/screen/login.dart';
import 'package:sura_driver/screen/orderdrivermain.dart';
import 'customerscreen.dart';
import 'firebase_options.dart';
import 'mainscreen.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test App',
      debugShowCheckedModeBanner: false,
      home: CheckAuth(),
    );
  }
}

class CheckAuth extends StatefulWidget {
  @override
  _CheckAuthState createState() => _CheckAuthState();
}

class _CheckAuthState extends State<CheckAuth> {
  bool _isLoading = true;
  int? _userId;
  int? _userRole;
  String? _username;

  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn();
  }

  Future<void> _checkIfLoggedIn() async {
    SharedPreferences localStorage = await SharedPreferences.getInstance();

    final token = localStorage.getString('token');
    final username = localStorage.getString('username');
    final userId = localStorage.getInt('user_id');
    final userRole = localStorage.getInt('role');
    final isLoggedIn = localStorage.getBool('is_logged_in') ?? false;

    // Check if user is properly logged in with all required data
    if (isLoggedIn && token != null && username != null && userId != null && userRole != null) {
      setState(() {
        _username = username;
        _userId = userId;
        _userRole = userRole;
      });
    } else {
      // Clear invalid login data
      await localStorage.remove('token');
      await localStorage.remove('username');
      await localStorage.remove('user_id');
      await localStorage.remove('role');
      await localStorage.remove('is_logged_in');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    Widget child;

    if (_username == null || _userId == null || _userRole == null) {
      // Not logged in - go to login screen
      child = Login();
      print("User not logged in - showing login screen");
    } else {
      // Logged in - navigate based on role
      if (_userRole == 3) {
        // Driver role
        child = MainScreen(id: _userId!);
        print("User is driver - navigating to MainScreen");
      } else if (_userRole == 2) {
        // Customer role
        child = Customerscreen(id: _userId!); // Make sure you have this screen
        print("User is customer - navigating to Customerscreen");
      } else {
        // Unknown role - go to login
        child = Login();
        print("Unknown user role - showing login screen");
      }
    }

    return Scaffold(
      body: child,
    );
  }
}