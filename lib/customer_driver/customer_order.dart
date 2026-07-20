import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../app_text.dart';

import '../color/color.dart';

class CustomerOrder extends StatefulWidget {
  @override
  _CustomerOrderState createState() => _CustomerOrderState();
}

class _CustomerOrderState extends State<CustomerOrder> {
  List<dynamic> orders = [];
  int? expandedIndex;

  final List<String> statuses = [
    'Pending',
    'Confirmed',
    'Delivered',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('user_id');
    final response = await http
        .get(Uri.parse(Url.url + '/api/mobile/order/merchant?user_id=$userId'));

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      if (jsonBody['success'] == true) {
        setState(() {
          orders = jsonBody['data'];
        });
      }
    } else {
      print('Failed to load orders: ${response.statusCode}');
    }
  }

  Color statusColor(int status) {
    switch (status) {
      case 1:
        return Colors.orange; // Pending
      case 2:
        return Colors.blue; // Confirmed
      case 3:
        return Colors.green; // Delivered
      case 4:
        return Colors.red; // Cancelled
      default:
        return Colors.grey;
    }
  }

  String statusText(int status) {
    switch (status) {
      case 1:
        return 'шинэ';
      case 2:
        return 'жолоочид';
      case 3:
        return 'хүргэгдсэн';
      case 4:
        return 'буцаасан';
      default:
        return 'Unknown';
    }
  }

  void updateStatus(int index, int newStatus) {
    setState(() {
      orders[index]['status'] = newStatus;
      expandedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Татан авалт',
            style: appText(color: Colors.white, fontSize: 15)),
        backgroundColor: Color(0xFF0e0e6e),
      ),
      backgroundColor: Colors.white,
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final isExpanded = expandedIndex == index;
          return Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Merchant & Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            expandedIndex = isExpanded ? null : index;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor(order['status']),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText(order['status']),
                            style: appText(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        children: List.generate(statuses.length, (i) {
                          final selected = (i + 1) == order['status'];
                          return ChoiceChip(
                            label: Text(
                              statuses[i],
                              style: appText(
                                  fontSize: 12,
                                  color:
                                      selected ? Colors.white : Colors.black),
                            ),
                            selected: selected,
                            selectedColor: Colors.blueAccent,
                            onSelected: (_) => updateStatus(index, i + 1),
                          );
                        }),
                      ),
                    ),

                  const SizedBox(height: 8),
                  Text(order['address'],
                      style: appText(
                          fontSize: 13, color: Colors.grey[800])),
                  const SizedBox(height: 6),
                  Text('📞 ${order['phone']}',
                      style: appText(
                          fontSize: 13, color: Colors.grey[700])),
                  const SizedBox(height: 6),
                  Text('💬 ${order['comment']}',
                      style: appText(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600])),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => _buildOrderFormDialog(),
          );
        },
        backgroundColor: Color(0xFF0e0e6e),
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'Шинэ хүргэлт нэмэх',
      ),
    );
  }

  Widget _buildOrderFormDialog() {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    final TextEditingController commentController = TextEditingController();

    InputDecoration _inputDecoration(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: appText(color: Colors.deepOrange),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.deepOrange.shade200, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.deepOrange, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: Colors.deepOrange.shade50.withOpacity(0.3),
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Text(
        'Шинэ захиалга',
        style: appText(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: Colors.deepOrange.shade700,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration('Утасны дугаар'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Утас оруулна уу' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: addressController,
                decoration: _inputDecoration('Хаяг'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Хаяг оруулна уу' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: commentController,
                maxLines: 3,
                decoration: _inputDecoration('Тайлбар'),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.deepOrange,
            textStyle: appText(fontWeight: FontWeight.w600),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Болих'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle:
                appText(fontWeight: FontWeight.w700, fontSize: 16),
            shadowColor: Colors.deepOrangeAccent,
            elevation: 5,
          ),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              int? userId = prefs.getInt('user_id');

              final response = await http.post(
                Uri.parse('${Url.url}/api/order'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'merchant_id': userId,
                  'phone': phoneController.text,
                  'address': addressController.text,
                  'comment': commentController.text,
                }),
              );

              if (response.statusCode == 200 || response.statusCode == 201) {
                Navigator.of(context).pop();
                fetchOrders(); // refresh the order list
              } else {
                print('Error creating order: ${response.body}');
              }
            }
          },
          child: Text(
            'Хадгалах',
            style: appText(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
