import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app_text.dart';
import '../color/color.dart'; // Make sure Url.url is defined here

class CustomerStat extends StatefulWidget {
  final int merchantId;
  final int status;

  const CustomerStat({
    Key? key,
    required this.merchantId,
    required this.status,
  }) : super(key: key);

  @override
  State<CustomerStat> createState() => _CustomerStatState();
}

class _CustomerStatState extends State<CustomerStat> {
  List<dynamic> deliveries = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDeliveries();
  }

  Future<void> fetchDeliveries() async {
    final url = Uri.parse(
      '${Url.url}/api/mobile/delivery/eachstatuscustomer/${widget.merchantId}/${widget.status}',
    );
    print(url);
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        setState(() {
          deliveries = json['data'] ?? [];
        });
      } else {
        throw Exception('Failed to load deliveries');
      }
    } catch (e) {
      debugPrint('Error fetching deliveries: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery) {
    final merchant = delivery['merchant'];
    final merchantName = (merchant != null && merchant is Map && merchant['username'] != null)
        ? merchant['username']
        : 'Unknown Merchant';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB), // very light gray-blue tone
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF6C63FF)), // pastel indigo
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  delivery['address'] ?? 'Хаяг байхгүй',
                  style: appText(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 20, color: Color(0xFF00B894)), // pastel green
              const SizedBox(width: 8),
              Text(
                delivery['phone'] ?? '',
                style: appText(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          if (delivery['comment'] != null &&
              delivery['comment'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_outlined, size: 20, color: Color(0xFFFFB347)), // soft orange
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    delivery['comment'],
                    style: appText(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF636E72),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Статус: ${widget.status}',
          style: appText(color: Colors.white, fontSize: 16),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : deliveries.isEmpty
          ? const Center(child: Text('Хоосон байна'))
          : ListView.builder(
        itemCount: deliveries.length,
        itemBuilder: (context, index) {
          return _buildDeliveryCard(deliveries[index]);
        },
      ),
    );
  }
}
