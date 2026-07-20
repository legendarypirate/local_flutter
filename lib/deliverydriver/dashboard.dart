import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/deliverydriver/delstat.dart';
import '../app_text.dart';

import '../color/color.dart'; // Make sure Url.url is defined here

class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool isLoading = true;
  int? userId; // 👈 Add this

  List<dynamic> reportData = [];
  Map<String, Color> statusColors = {};

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    try {
      await _fetchReportData();

    } catch (e) {
      debugPrint('Dashboard error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchReportData() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt('user_id'); // 👈 Assign it here

    if (userId == null) throw Exception('user_id not found in prefs');

    final url = Uri.parse(
        '${Url.url}/api/mobile/delivery/reportdata?driver_id=$userId');

    final res = await http.get(url);

    // 👇 Add this line to print the raw response
    debugPrint('API Response: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch report data');
    }

    reportData = (jsonDecode(res.body)['data'] as List?) ?? [];
    print(reportData);
    statusColors = {
      for (final s in reportData)
        s['status'].toString().toLowerCase(): _mapColor(s['color'])
    };
  }

  Color _mapColor(dynamic colorName) {
    switch ((colorName ?? '').toString().toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'yellow':
        return Colors.yellow;
      case 'purple':
        return Colors.purple;
      case 'cyan':
        return Colors.cyan;
      case 'brown':
        return Colors.brown;
      case 'indigo':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForStatus(String status) {
    switch (status) {
      case 'жолоочид':
        return Icons.local_shipping;
      case 'жолооч хүлээж авсан':
        return Icons.move_to_inbox;
      case 'хаягаар очсон':
        return Icons.location_on;
      case 'хүргэгдсэн':
        return Icons.check_circle;
      case 'дараа авна':
        return Icons.schedule;
      case 'буцаасан':
        return Icons.reply;
      case 'цуцалсан':
        return Icons.cancel;
      default:
        return Icons.label;
    }
  }

  Widget _buildCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required int status,         // 👈 add this
    required int driverId,          // 👈 pass userId here
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Delstat(
              driverId: driverId,
              status: status,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: color.withOpacity(0.4), width: 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: appText(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87)),
            ),
            Text('$count',
                style: appText(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: Text(
          'Хянах самбар',
          style: appText(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // ← This makes back button white
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: reportData
              .where((s) => s['status'].toString().toLowerCase() != 'шинэ') // exclude "шинэ"
              .map((s) {
            final statusText = s['status'].toString();
            final statusId = s['id']; // 👈 get int value
            final count = s['count'] ?? 0;
            final color = statusColors[statusText.toLowerCase()] ?? Colors.grey;
            final icon = _getIconForStatus(statusText.toLowerCase());

            return _buildCard(
              title: statusText,
              count: count,
              color: color,
              icon: icon,
              status: statusId,      // 👈 now passing int
              driverId: userId!,
            );
          }).toList(),

        ),
      ),
    );
  }
}
