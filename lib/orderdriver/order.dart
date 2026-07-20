import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../app_text.dart';

import '../color/color.dart';
import 'detail.dart';

class OrderScreen extends StatefulWidget {
  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  int? expandedIndex;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? id = prefs.getInt('user_id');
    final url = Uri.parse(Url.url + '/api/mobile/order/driver/$id/status-2');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> data = decoded['data'];

        setState(() {
          orders = data
              .map((item) => {
                    'id': item['id'], // Add this line to keep order ID!
                    'merchant': item['merchant']['username'],
                    'phone': item['phone'],
                    'address': item['address'],
                    'comment': item['comment'],
                    'status':
                        item['status_text'], // Always "Жолоочид хуваарилсан"
                  })
              .toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (e) {
      print('Error fetching orders: $e');
      setState(() => isLoading = false);
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.deepOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Orders',
          style: appText(color: Colors.white, fontSize: 15),
        ),
        backgroundColor: Color(0xFF0e0e6e),
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : orders.isEmpty
              ? Center(
                  child: Text('Хүргэлт алга',
                      style: appText(fontSize: 14)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final isExpanded = expandedIndex == index;

                    return InkWell(
                        onTap: () {
                          // Navigate to OrderDetailScreen, passing the order id
                          // Assuming your orders data has an 'id' field as well
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  OrderDetailScreen(orderId: order['id']),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Merchant & Status Row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      order['merchant'] ?? '',
                                      style: appText(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            statusColor(order['status'] ?? ''),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        order['status'] ?? '',
                                        style: appText(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),
                                Text(order['address'] ?? '',
                                    style: appText(fontSize: 13)),
                                const SizedBox(height: 6),
                                Text('📞 ${order['phone']}',
                                    style: appText(fontSize: 13)),
                                const SizedBox(height: 6),
                                Text('💬 ${order['comment']}',
                                    style: appText(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                        ));
                  },
                ),
    );
  }
}
