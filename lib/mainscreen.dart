import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/deliverydriver/donedelivery.dart';
import 'package:sura_driver/deliverydriver/unpaiddelivery.dart';
import 'app_text.dart';

import 'customer_driver/user.dart';
import 'deliverydriver/delivery.dart';
import 'deliverydriver/homefordel.dart';
import 'orderdriver/doneorder.dart';
import 'orderdriver/order.dart';
import 'package:http/http.dart' as http;

import 'package:sura_driver/color/color.dart';

class MainScreen extends StatefulWidget {
  int id;

  MainScreen({
    required this.id,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _doneRefresh = 0;
  int _unpaidRefresh = 0;

  Widget _pageForIndex(int index) {
    switch (index) {
      case 0:
        return DeliveryListScreen();
      case 1:
        return Done(key: ValueKey('done-$_doneRefresh'));
      case 2:
        return UnpaidDone(key: ValueKey('unpaid-$_unpaidRefresh'));
      case 3:
        return OrderScreen();
      case 4:
        return SummaryScreen();
      case 5:
        return UserDetailScreen();
      default:
        return DeliveryListScreen();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      if (index == 1 && _selectedIndex != 1) _doneRefresh++;
      if (index == 2 && _selectedIndex != 2) _unpaidRefresh++;
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _pageForIndex(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Хүргэлт',
            backgroundColor: Colors.white,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box),
            label: 'Дууссан',
            backgroundColor: Colors.white,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payments_outlined),
            label: 'Аваагүй',
            backgroundColor: Colors.white,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Захиалга',
            backgroundColor: Colors.white,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: 'Тайлан',
            backgroundColor: Colors.white,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.man),
            label: 'Мэдээлэл',
            backgroundColor: Colors.white,
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: appText(fontSize: 11, fontWeight: FontWeight.w500),
        unselectedLabelStyle: appText(fontSize: 10),
        onTap: _onItemTapped,
      ),
    );
  }
}
