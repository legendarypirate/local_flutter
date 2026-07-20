import 'package:flutter/material.dart';

import '../orderdriver/doneorder.dart';
import '../orderdriver/order.dart';

// import 'package:mewalk/screen/home/home.dart';
// import 'package:mewalk/screen/income/monthincome.dart';
// import 'package:mewalk/screen/lottery/lottery.dart';
// import 'package:mewalk/screen/profile/profile.dart';

class OrderDriverMain extends StatefulWidget {
  // LoginScreen({Key? key}) : super(key: key);
  String name;

  OrderDriverMain({
    required this.name,
  });
  @override
  State<OrderDriverMain> createState() => _OrderDriverMainState();
}

class _OrderDriverMainState extends State<OrderDriverMain> {
  int _selectedIndex = 0;
  static const TextStyle optionStyle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.bold);
  late List<Widget> _widgetOptions;

  @override
  void initState() {
    // TODO: implement initState
    _widgetOptions = <Widget>[
      OrderScreen(),
      Doneorder(
        name: widget.name,
        id: 1,
      ),
    ];
    super.initState();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Захиалга',
            backgroundColor: Colors.white,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code),
            label: 'Дууссан',
            backgroundColor: Colors.white,
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
