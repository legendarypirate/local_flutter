import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/deliverydriver/detaildelivery.dart';
import 'package:http/http.dart' as http;
import '../app_text.dart';

import '../color/color.dart';
import '../screen/login.dart';
import 'dashboard.dart';

String _digitsOnlyPhone(String raw) => raw.replaceAll(RegExp(r'\D'), '');

class Delivery {
  final int id;
  final String phone;
  String status;
  final DateTime createdDate;
  String comment;
  String price;
  final String address;
  List<String> possibleStatuses;
  final String merchantUsername;
  String? selectedColor; // 🔹 New property for color tag
  String? notPickedRequestStatus;

  Delivery({
    required this.id,
    required this.phone,
    required this.status,
    required this.createdDate,
    required this.comment,
    required this.price,
    required this.address,
    required this.merchantUsername,
    this.selectedColor, // 🔹 Initialize with null (no color)
    this.notPickedRequestStatus,
    this.possibleStatuses = const [
      "Pending",
      "In Transit",
      "Delivered",
      "Cancelled"
    ],
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    String? notPickedStatus;
    final npr = json['not_picked_requests'];
    if (npr is List && npr.isNotEmpty && npr.first is Map) {
      notPickedStatus = npr.first['status']?.toString();
    }
    return Delivery(
      id: json['id'],
      phone: json['phone']?.toString() ?? '',
      status: _statusFromCode(json['status']),
      createdDate: DateTime.parse(json['createdAt']),
      comment: json['comment'] ?? '',
      address: json['address'],
      merchantUsername: json['merchant']?['username'] ?? '-',
      price: json['price'],
      notPickedRequestStatus: notPickedStatus,
    );
  }

  static String _statusFromCode(int statusCode) {
    switch (statusCode) {
      case 1:
        return "Pending";
      case 2:
        return "Жолоочид";
      case 3:
        return "Delivered";
      case 4:
        return "Cancelled";
      default:
        return "Unknown";
    }
  }

  static int _codeFromStatus(String status) {
    switch (status) {
      case "Pending":
        return 1;
      case "Жолоочид":
        return 2;
      case "Delivered":
        return 3;
      case "Cancelled":
        return 4;
      default:
        return 0;
    }
  }

  int get statusCode => _codeFromStatus(status);
}

class DeliveryListScreen extends StatefulWidget {
  @override
  _DeliveryListScreenState createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> {
  List<Delivery> deliveries = [];
  bool isLoading = true;
  Set<int> selectedDeliveries = Set<int>(); // 🔹 Track selected deliveries
  bool isSelectionMode = false; // 🔹 Selection mode state

  final TextEditingController _phoneSearchController = TextEditingController();
  String _phoneDigitsQuery = '';

  List<Delivery> get _visibleDeliveries {
    if (_phoneDigitsQuery.isEmpty) return deliveries;
    return deliveries
        .where((d) =>
            _digitsOnlyPhone(d.phone).contains(_phoneDigitsQuery))
        .toList();
  }

  bool get _phoneFilterActive => _phoneDigitsQuery.isNotEmpty;

  // Available colors for tagging
  final List<Map<String, dynamic>> availableColors = [
    {'name': 'blue', 'color': Colors.blue[100]!, 'border': Colors.blue},
    {'name': 'green', 'color': Colors.green[100]!, 'border': Colors.green},
    {'name': 'orange', 'color': Colors.orange[100]!, 'border': Colors.orange},
  ];

  List<String> statuses = [
    'Pending',
    'Жолоочид',
    'Delivered',
    'Cancelled',
  ];

  // Load color tags from SharedPreferences
  Future<Map<int, String>> _loadColorTags() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? colorTagsJson = prefs.getString('delivery_color_tags');
    if (colorTagsJson != null) {
      Map<String, dynamic> tagsMap = json.decode(colorTagsJson);
      return tagsMap.map((key, value) => MapEntry(int.parse(key), value.toString()));
    }
    return {};
  }

  // Save color tags to SharedPreferences
  Future<void> _saveColorTags(Map<int, String> colorTags) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, String> tagsMap = colorTags.map((key, value) => MapEntry(key.toString(), value));
    await prefs.setString('delivery_color_tags', json.encode(tagsMap));
  }

  // Apply color to selected deliveries
  Future<void> _applyColorToSelected(String colorName) async {
    Map<int, String> colorTags = await _loadColorTags();

    for (int deliveryId in selectedDeliveries) {
      colorTags[deliveryId] = colorName;
    }

    await _saveColorTags(colorTags);

    // Update local state
    setState(() {
      for (var delivery in deliveries) {
        if (selectedDeliveries.contains(delivery.id)) {
          delivery.selectedColor = colorName;
        }
      }
      selectedDeliveries.clear();
      isSelectionMode = false;
    });
  }

  // Get background color for delivery
  Color _getDeliveryBackgroundColor(Delivery delivery) {
    if (selectedDeliveries.contains(delivery.id)) {
      return Colors.grey[300]!; // Grey background for selected items
    }

    if (delivery.selectedColor != null) {
      final colorConfig = availableColors.firstWhere(
            (color) => color['name'] == delivery.selectedColor,
        orElse: () => availableColors[0],
      );
      return colorConfig['color'];
    }

    return Colors.white; // Default background
  }

  // Get border color for delivery
  Color _getDeliveryBorderColor(Delivery delivery) {
    if (delivery.selectedColor != null) {
      final colorConfig = availableColors.firstWhere(
            (color) => color['name'] == delivery.selectedColor,
        orElse: () => availableColors[0],
      );
      return colorConfig['border'];
    }

    return Colors.grey[300]!; // Default border
  }

  Future<void> saveOrderLocally() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> order = deliveries.map((d) => d.id.toString()).toList();
    await prefs.setStringList('delivery_order', order);
  }

  Future<void> loadOrderLocally() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedOrder = prefs.getStringList('delivery_order');
    if (savedOrder != null && deliveries.isNotEmpty) {
      deliveries.sort((a, b) {
        int indexA = savedOrder.indexOf(a.id.toString());
        int indexB = savedOrder.indexOf(b.id.toString());
        if (indexA == -1) indexA = deliveries.length;
        if (indexB == -1) indexB = deliveries.length;
        return indexA.compareTo(indexB);
      });
    }
  }

  Future<void> fetchDeliveries() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('user_id');
    final url =
    Uri.parse(Url.url + '/api/mobile/delivery/driver/$userId/status-2');
    print(url);
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List data = jsonResponse['data'];

        // Load color tags
        Map<int, String> colorTags = await _loadColorTags();

        setState(() {
          deliveries = data.map((item) {
            final delivery = Delivery.fromJson(item);
            delivery.selectedColor = colorTags[delivery.id];
            return delivery;
          }).toList();
        });

        await loadOrderLocally(); // Apply saved order
      } else {
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to load deliveries: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updateStatus(int index, String newStatus) async {
    final delivery = deliveries[index];
    final url =
    Uri.parse(Url.url + '/api/mobile/delivery/${delivery.id}/status');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': Delivery._codeFromStatus(newStatus)}),
      );

      if (response.statusCode == 200) {
        setState(() {
          delivery.status = newStatus;
        });
      } else {
        print('Failed to update status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating status: $e');
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'жолоочид':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd – kk:mm').format(date);
  }

  void _toggleDeliverySelection(int deliveryId) {
    setState(() {
      if (selectedDeliveries.contains(deliveryId)) {
        selectedDeliveries.remove(deliveryId);
      } else {
        selectedDeliveries.add(deliveryId);
      }

      // Enable selection mode if any items are selected
      isSelectionMode = selectedDeliveries.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      selectedDeliveries.clear();
      isSelectionMode = false;
    });
  }

  @override
  void initState() {
    super.initState();
    fetchDeliveries();
  }

  @override
  void dispose() {
    _phoneSearchController.dispose();
    super.dispose();
  }

  Widget _buildDeliveryTile(Delivery delivery) {
    if (!deliveries.any((d) => d.id == delivery.id)) {
      return const SizedBox.shrink();
    }

    return InkWell(
      key: ValueKey(delivery.id),
      onTap: () {
        if (isSelectionMode) {
          _toggleDeliverySelection(delivery.id);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DeliveryDetailScreen(deliveryId: delivery.id),
            ),
          );
        }
      },
      onDoubleTap: () => _toggleDeliverySelection(delivery.id),
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _getDeliveryBorderColor(delivery),
            width: 2,
          ),
        ),
        color: _getDeliveryBackgroundColor(delivery),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (selectedDeliveries.contains(delivery.id))
                    Icon(
                      Icons.check_circle,
                      color: Colors.blue,
                      size: 20,
                    ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor(delivery.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      delivery.status,
                      style: appText(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (delivery.notPickedRequestStatus == 'pending') ...[
                const SizedBox(height: 6),
                Text(
                  '⏳ Авч гараагүй хүсэлт хүлээгдэж байна',
                  style: appText(fontSize: 11, color: Colors.orange.shade800),
                ),
              ] else if (delivery.notPickedRequestStatus == 'rejected') ...[
                const SizedBox(height: 6),
                Text(
                  '❌ Авч гараагүй хүсэлт татгалзсан',
                  style: appText(fontSize: 11, color: Colors.red.shade700),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    delivery.phone,
                    style: appText(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Үүссэн: ${formatDate(delivery.createdDate)}',
                    style: appText(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Үнэ',
                    style: appText(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '${delivery.price}₮',
                    style: appText(
                      color: Colors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on,
                      size: 14, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      delivery.address,
                      style: appText(
                        fontSize: 12,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
              if (delivery.selectedColor != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: availableColors
                        .firstWhere(
                          (color) => color['name'] == delivery.selectedColor,
                          orElse: () => availableColors[0],
                        )['border']
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Өнгөтэй',
                    style: appText(
                      fontSize: 10,
                      color: availableColors.firstWhere(
                        (color) => color['name'] == delivery.selectedColor,
                        orElse: () => availableColors[0],
                      )['border'],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.dashboard, color: Colors.white),
          tooltip: 'Dashboard',
          onPressed: () {
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => Dashboard()));
          },
        ),
        title: Text('Хүргэлт',
            style: appText(color: Colors.white, fontSize: 13)),
        backgroundColor: Color(0xFF0e0e6e),
        actions: [
          if (isSelectionMode) ...[
            IconButton(
              icon: Icon(Icons.clear, color: Colors.white),
              onPressed: _clearSelection,
              tooltip: 'Clear selection',
            ),
          ],
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => Login()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Selection info and color options
          if (isSelectionMode)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[50],
              child: Column(
                children: [
                  Text(
                    '${selectedDeliveries.length} хүргэлт сонгогдлоо',
                    style: appText(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Өнгө сонгох:',
                    style: appText(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: availableColors.map((colorConfig) {
                      return GestureDetector(
                        onTap: () => _applyColorToSelected(colorConfig['name']),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: colorConfig['color'],
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: colorConfig['border'],
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.check,
                            color: colorConfig['border'],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _phoneSearchController,
              keyboardType: TextInputType.phone,
              style: appText(),
              decoration: InputDecoration(
                hintText: 'Утсаар хайх (жишээ: 9909)',
                prefixIcon: const Icon(Icons.search, size: 22),
                suffixIcon: _phoneDigitsQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _phoneSearchController.clear();
                          setState(() => _phoneDigitsQuery = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (v) {
                setState(() {
                  _phoneDigitsQuery = _digitsOnlyPhone(v);
                });
              },
            ),
          ),
          if (_phoneFilterActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Text(
                'Хайлт идэвхтэй — эрэмбэлэх түр идэвхгүй',
                style: appText(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: Text(
              _phoneFilterActive
                  ? 'Нийт: ${deliveries.length} | Олдсон: ${_visibleDeliveries.length}'
                  : 'Нийт хүргэлт: ${deliveries.length}',
              style: appText(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _phoneFilterActive && _visibleDeliveries.isEmpty
                ? Center(
                    child: Text(
                      'Тохирох хүргэлт олдсонгүй',
                      style: appText(
                        fontSize: 15,
                        color: Colors.grey[600],
                      ),
                    ),
                  )
                : _phoneFilterActive
                    ? ListView(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 8),
                        children: _visibleDeliveries
                            .map((d) => _buildDeliveryTile(d))
                            .toList(),
                      )
                    : ReorderableListView(
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = deliveries.removeAt(oldIndex);
                        deliveries.insert(newIndex, item);
                      });
                      saveOrderLocally();
                    },
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 8),
                        children: [
                          for (final d in deliveries) _buildDeliveryTile(d),
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButton: isSelectionMode
          ? FloatingActionButton(
        onPressed: _clearSelection,
        child: Icon(Icons.clear),
        backgroundColor: Colors.red,
      )
          : null,
    );
  }
}