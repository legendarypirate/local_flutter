import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_text.dart';

class Customersummary extends StatefulWidget {
  @override
  State<Customersummary> createState() => _CustomersummaryState();
}

class _CustomersummaryState extends State<Customersummary> {
  late Future<Map<String, dynamic>> futureStats;

  Future<Map<String, dynamic>> fetchStats() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) {
      throw Exception('Хэрэглэгч олдсонгүй (user_id is null)');
    }

    final response = await http.get(
      Uri.parse(
          'https://api.localexpress.mn/api/delivery/statistic?merchant_id=$userId'),
    );

    print('https://api.localexpress.mn/api/delivery/statistic?merchant_id=$userId');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success']) {
        return data;
      } else {
        throw Exception('Амжилтгүй статистик');
      }
    } else {
      throw Exception('API дуудлагад алдаа гарлаа');
    }
  }

  @override
  void initState() {
    super.initState();
    futureStats = fetchStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Нийт мэдээлэл',
          style: appText(color: Colors.white, fontSize: 15),
        ),
        backgroundColor: Color(0xFF0e0e6e),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: futureStats,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Алдаа: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final deliveries = (data['deliveries_today'] ?? 0).toInt();
          final orders = (data['orders_today'] ?? 0).toInt();
          final goods = (data['goods_today'] ?? 0).toInt();
          final successRate = ((data['success_rate_percent'] ?? 0) as num).round();


          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildSummaryCard(
                    'хүргэлт', deliveries, Colors.blue, Icons.local_shipping),
                _buildSummaryCard(
                    'захиалга', orders, Colors.green, Icons.receipt_long),
                _buildSummaryCard(
                    'бараа', goods, Colors.deepPurple, Icons.inventory),
                _buildSummaryCard(
                    'Амжилттай', successRate, Colors.orange, Icons.percent),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, int value, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 35, color: color),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: appText(
                fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: appText(
                fontSize: 14, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
