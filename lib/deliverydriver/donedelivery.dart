import 'dart:convert';

import '../app_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/deliverydriver/detaildelivery.dart';
import 'package:http/http.dart' as http;

import '../color/color.dart';
import '../screen/login.dart';
import 'dashboard.dart';
import 'delivery_done_shared.dart';

class Done extends StatefulWidget {
  const Done({Key? key}) : super(key: key);

  @override
  _DoneState createState() => _DoneState();
}

class _DoneState extends State<Done> {
  List<DoneDelivery> deliveries = [];
  int? expandedIndex;
  bool isLoading = true;

  // Date filter state
  DateTime? _startDate;
  DateTime? _endDate;

  List<String> statuses = [
    'Pending',
    'Хуваарилсан',
    'хүргэсэн',
    'Cancelled',
  ];

  Future<void> _markDeliveredAsPaid(DoneDelivery delivery) async {
    if (delivery.statusCode != 3) return;
    if (delivery.isPaid) return;

    final ok = await updateDeliveryIsPaid(delivery.id, true);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Тооцоо тэмдэглэхэд алдаа гарлаа')),
        );
      }
      return;
    }

    setState(() {
      delivery.isPaid = true;
    });
  }

  Future<void> fetchDeliveries({DateTime? startDate, DateTime? endDate}) async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final data = await fetchDoneDeliveries(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );
      setState(() {
        deliveries = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load deliveries: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> updateStatus(int index, String newStatus) async {
    final delivery = deliveries[index];
    final url =
    Uri.parse('${Url.url}/api/mobile/delivery/${delivery.id}/status');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': DoneDelivery.codeFromStatus(newStatus)}),
      );

      if (response.statusCode == 200) {
        setState(() {
          delivery.status = newStatus;
          expandedIndex = null;
        });
      } else {
        debugPrint('Failed to update status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd – kk:mm').format(date);
  }

  /// Opens a date-range picker and refreshes the delivery list according to the
  /// selected range.
  Future<void> _pickDateRange() async {
    final now = DateTime.now();

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: now, end: now),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        isLoading = true;
      });

      await fetchDeliveries(startDate: _startDate, endDate: _endDate);
    }
  }

  /// Clears the date filter, reverting to the backend default (today only).
  Future<void> _clearDateFilter() async {
    setState(() {
      _startDate = null;
      _endDate = null;
      isLoading = true;
    });

    await fetchDeliveries();
  }

  @override
  void initState() {
    super.initState();
    fetchDeliveries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.dashboard, color: Colors.white),
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
          IconButton(
            icon: const Icon(Icons.filter_alt, color: Colors.white),
            tooltip: 'Date filter',
            onPressed: _pickDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Clear filter',
            onPressed: _clearDateFilter,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
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
          ? const Center(child: CircularProgressIndicator())
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Нийт хүргэлт: ${deliveries.length}',
                  style: appText(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Тооцоо авсан: ${deliveries.where((d) => d.isPaid).length}',
                        style: appText(
                          fontSize: 12,
                          color: Colors.green[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      '${DateFormat('yyyy-MM-dd').format(_startDate!)} → ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                      style: appText(
                          fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: Colors.blueGrey,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearDateFilter,
                  )
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: deliveries.length,
              itemBuilder: (context, index) {
                final delivery = deliveries[index];
                final isExpanded = expandedIndex == index;

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DeliveryDetailScreen(deliveryId: delivery.id),
                      ),
                    );
                  },
                  onDoubleTap: () {
                    _markDeliveredAsPaid(delivery);
                  },
                  child: Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    color: delivery.isPaid
                        ? Colors.blue[50]  // Blue background for paid
                        : Colors.white,    // Normal background
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: doneStatusColor(delivery.status),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    delivery.status,
                                    style: appText(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12),
                                  ),
                                ),
                              ),
                              if (delivery.isPaid)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Тооцоо авсан',
                                        style: appText(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (isExpanded)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 6,
                                children: statuses.map((status) {
                                  final selected =
                                      status == delivery.status;
                                  return ChoiceChip(
                                    label: Text(status,
                                        style: appText(
                                            fontSize: 11,
                                            color: selected
                                                ? Colors.white
                                                : Colors.black)),
                                    selected: selected,
                                    selectedColor: Colors.blueAccent,
                                    onSelected: (selected) {
                                      if (selected)
                                        updateStatus(index, status);
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(
                              'Үүсэн: ${formatDate(delivery.createdDate)}',
                              style: appText(
                                  color: Colors.grey[700], fontSize: 11)),
                          const SizedBox(height: 10),
                          Text('Утас: ${delivery.phone}',
                              style: appText(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(delivery.comment,
                                    style: appText(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: Text('₮ ${delivery.price}',
                                    textAlign: TextAlign.right,
                                    style: appText(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[700])),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(delivery.address,
                              style: appText(
                                  fontSize: 11, color: Colors.grey[800])),
                          SizedBox(height: 4),
                          Text(
                            'Давхар дарж тооцоо авсан эсэхийг тэмдэглэнэ',
                            style: appText(
                              fontSize: 9,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}