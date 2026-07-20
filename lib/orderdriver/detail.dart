import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_text.dart';

import '../color/color.dart';
import '../mainscreen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? order;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchOrder();
  }

  Future<void> fetchOrder() async {
    final url = Uri.parse(Url.url + '/api/order/${widget.orderId}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() {
            order = jsonResponse['data'];
            isLoading = false;
            error = null;
          });
        } else {
          setState(() {
            error = 'Failed to load order details';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = 'Server error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  String formatDate(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Захиалгын дэлгэрэнгүй',
            style: appText(color: Colors.white, fontSize: 16),
          ),
          backgroundColor: Colors.deepOrange,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Захиалгын дэлгэрэнгүй',
            style: appText(color: Colors.white, fontSize: 16),
          ),
          backgroundColor: Colors.deepOrange,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(child: Text(error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Захиалгын дэлгэрэнгүй',
          style: appText(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: Colors.deepOrange,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Захиалгын ID: ${order!['id'] ?? 'N/A'}",
                    style: appText(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Захиалагч: ${order!['merchant']?['username'] ?? 'N/A'}",
                    style: appText(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Утас: ${order!['phone'] ?? 'N/A'}",
                    style:
                        appText(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Хаяг: ${order!['address'] ?? 'N/A'}",
                    style:
                        appText(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Тайлбар: ${order!['comment'] ?? 'N/A'}",
                    style:
                        appText(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Үүсгэсэн огноо: ${formatDate(order!['createdAt'] ?? '')}",
                    style:
                        appText(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Төлөв: ${order!['status_text'] ?? 'N/A'}",
                    style: appText(
                      fontSize: 14,
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4 buttons in grid (or Wrap for flexible layout)
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              physics: NeverScrollableScrollPhysics(),
              childAspectRatio: 1,
              children: [
                _actionButton("Хүргэсэн", Icons.check_circle, Colors.green,
                    () async {
                  final confirmed = await showConfirmationDialog(
                      context, 'Та итгэлтэй байна уу?');
                  if (confirmed == true) {
                    _markAsDelivered();
                  }
                }),
                _actionButton("Цуцалсан", Icons.cancel, Colors.red, () async {
                  final confirmed = await showConfirmationDialog(
                      context, 'Та итгэлтэй байна уу?');
                  if (confirmed == true) {
                    _markAsDeclined();
                  }
                }),
                _actionButton("Утсаар ярих", Icons.phone, Colors.indigo, () {
                  final phone = order!['phone'] ?? '';
                  if (phone.isNotEmpty) {
                    _callPhoneNumber(phone);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Утасны дугаар олдсонгүй')));
                  }
                }),
                _actionButton("Газрын зураг", Icons.map, Colors.teal, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Газрын зураг pressed')));
                }),
              ],
            ),
            // You can add more details, e.g. list of ordered items here if available.
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        textStyle: appText(fontSize: 18),
      ),
    );
  }

  final String baseUrl = Url.url + '/api/mobile/order/complete';

  Future<void> _markAsDelivered() async {
    final url = Uri.parse('$baseUrl/${widget.orderId}');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"status": 3}),
      );

      if (response.statusCode == 200) {
        print('Order marked as delivered: ${response.body}');
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt('user_id'); // ✅ Retrieve from shared

        // ✅ Navigate to MainScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(id: userId!),
          ),
        );
      } else {
        print('Failed to mark as delivered: ${response.statusCode}');
      }
    } catch (e) {
      print('Error marking as delivered: $e');
    }
  }

  Future<void> _markAsDeclined() async {
    final url = Uri.parse('$baseUrl/${widget.orderId}');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"status": 5}),
      );

      if (response.statusCode == 200) {
        print('Order marked as declined: ${response.body}');
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt('user_id'); // ✅ Retrieve from shared

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(id: userId!),
          ),
        );
      } else {
        print('Failed to mark as declined: ${response.statusCode}');
      }
    } catch (e) {
      print('Error marking as declined: $e');
    }
  }

  Future<bool?> showConfirmationDialog(BuildContext context, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
              SizedBox(width: 8),
              Text(
                'Анхааруулга',
                style: appText(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: appText(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.close, color: Colors.red),
              label: Text(
                'Үгүй',
                style: appText(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton.icon(
              icon: Icon(Icons.check_circle, color: Colors.green),
              label: Text(
                'Тийм',
                style: appText(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  Future<void> _callPhoneNumber(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Утасны дугаарыг дуудахад алдаа гарлаа')),
      );
    }
  }
}
