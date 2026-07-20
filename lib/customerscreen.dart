import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/deliverydriver/donedelivery.dart';
import 'app_text.dart';

import 'customer_driver/CustomerSummary.dart';
import 'customer_driver/customer_order.dart';
import 'customer_driver/delivery.dart';
import 'customer_driver/report.dart';
import 'deliverydriver/delivery.dart';
import 'deliverydriver/homefordel.dart';
import 'deliverydriver/ware.dart';
import 'orderdriver/doneorder.dart';
import 'orderdriver/order.dart';
import 'package:http/http.dart' as http;

import 'package:sura_driver/color/color.dart';

class Customerscreen extends StatefulWidget {
  int id;

  Customerscreen({
    required this.id,
  });

  @override
  State<Customerscreen> createState() => _CustomerscreenState();
}

class _CustomerscreenState extends State<Customerscreen> {
  int _selectedIndex = 0;
  late List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      DeliveryCustomer(),
      CustomerOrder(),
      GoodListScreen(),
      Customersummary(),
      CustomerReport(),
    ];
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
            icon: Icon(Icons.local_shipping), // 🚚 Хүргэлт (Delivery)
            label: 'Хүргэлт',
            backgroundColor: Colors.white,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long), // 📋 Захиалга (Orders)
            label: 'Захиалга',
            backgroundColor: Colors.white,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warehouse), // 🏬 Агуулах (Warehouse)
            label: 'Агуулах',
            backgroundColor: Colors.white,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info), // ℹ️ Мэдээлэл (Info)
            label: 'Мэдээлэл',
            backgroundColor: Colors.white,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report), // ℹ️ Мэдээлэл (Info)
            label: 'Тайлан',
            backgroundColor: Colors.white,
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle:
            appText(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: appText(fontSize: 11),
        onTap: _onItemTapped,
      ),
    );
  }
}
