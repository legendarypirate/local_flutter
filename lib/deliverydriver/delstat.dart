import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../color/color.dart';
import '../app_text.dart';
import 'detaildelivery.dart'; // Make sure Url.url is defined here

class Delstat extends StatefulWidget {
  final int driverId;
  final int status;

  const Delstat({
    Key? key,
    required this.driverId,
    required this.status,
  }) : super(key: key);

  @override
  State<Delstat> createState() => _DelstatState();
}

class _DelstatState extends State<Delstat> {
  List<dynamic> deliveries = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDeliveries();
  }

  Future<void> fetchDeliveries() async {
    final url = Uri.parse(
      '${Url.url}/api/mobile/delivery/eachstatus/${widget.driverId}/${widget.status}',
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

    return
      InkWell(
          key: ValueKey(delivery['id']), // ← Энд key өгнө
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeliveryDetailScreen(
                    deliveryId:delivery['id']),
              ),
            );
          },
          child:
          Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            merchantName,
            style: appText(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  delivery['address'] ?? 'No Address',
                  style: appText(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                delivery['phone'] ?? '',
                style: appText(fontSize: 14),
              ),
            ],
          ),
          if (delivery['comment'] != null &&
              delivery['comment'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.comment, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    delivery['comment'],
                    style: appText(fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ));
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
