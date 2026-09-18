import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../color/color.dart';

class DoneDelivery {
  final int id;
  final String phone;
  String status;
  final DateTime createdDate;
  String comment;
  String price;
  final String address;
  bool isPaid;
  bool isRural;

  DoneDelivery({
    required this.id,
    required this.phone,
    required this.status,
    required this.createdDate,
    required this.price,
    required this.comment,
    required this.address,
    this.isPaid = false,
    this.isRural = false,
  });

  factory DoneDelivery.fromJson(Map<String, dynamic> json) {
    return DoneDelivery(
      id: json['id'],
      phone: json['phone'],
      status: statusFromCode(json['status']),
      createdDate: DateTime.parse(json['createdAt']),
      comment: json['comment'] ?? '',
      price: json['price']?.toString() ?? '',
      address: json['address'] ?? '',
      isPaid: json['is_paid'] == true,
      isRural: json['is_rural'] == true,
    );
  }

  static String statusFromCode(dynamic statusCode) {
    switch (statusCode) {
      case 1:
        return 'Pending';
      case 2:
        return 'Хуваарилсан';
      case 3:
        return 'хүргэсэн';
      case 4:
        return 'Cancelled';
      default:
        return 'Буцаасан';
    }
  }

  static int codeFromStatus(String status) {
    switch (status) {
      case 'Pending':
        return 1;
      case 'Хуваарилсан':
        return 2;
      case 'хүргэсэн':
        return 3;
      case 'Cancelled':
        return 4;
      default:
        return 0;
    }
  }

  int get statusCode => codeFromStatus(status);
}

class DoneDeliveriesPage {
  final List<DoneDelivery> items;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;

  const DoneDeliveriesPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
  });
}

Future<List<DoneDelivery>> fetchDoneDeliveries({
  required int userId,
  DateTime? startDate,
  DateTime? endDate,
  bool? unpaidOnly,
}) async {
  final result = await fetchDoneDeliveriesPage(
    userId: userId,
    startDate: startDate,
    endDate: endDate,
    unpaidOnly: unpaidOnly,
  );
  return result.items;
}

Future<DoneDeliveriesPage> fetchDoneDeliveriesPage({
  required int userId,
  DateTime? startDate,
  DateTime? endDate,
  bool? unpaidOnly,
  int page = 1,
  int limit = 50,
}) async {
  final formatter = DateFormat('yyyy-MM-dd');
  final params = <String, String>{
    'page': page.toString(),
    'limit': limit.toString(),
  };

  if (unpaidOnly == true) {
    params['is_paid'] = 'false';
  } else if (unpaidOnly == false) {
    params['is_paid'] = 'true';
  }

  if (startDate != null && endDate != null) {
    params['startDate'] = formatter.format(startDate);
    params['endDate'] = formatter.format(endDate);
  }

  final query =
      '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';

  final url = Uri.parse('${Url.url}/api/mobile/delivery/driver/$userId/status-3$query');
  debugPrint('Fetching done deliveries from: $url');

  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw Exception('Failed to load deliveries (${response.statusCode})');
  }

  final jsonResponse = json.decode(response.body);
  final List data = jsonResponse['data'] ?? [];
  final items = data.map((item) => DoneDelivery.fromJson(item)).toList();
  final pagination = jsonResponse['pagination'];

  if (pagination is Map) {
    final total = pagination['total'] is int
        ? pagination['total'] as int
        : int.tryParse(pagination['total']?.toString() ?? '') ?? items.length;
    final currentPage = pagination['page'] is int
        ? pagination['page'] as int
        : int.tryParse(pagination['page']?.toString() ?? '') ?? page;
    final pageLimit = pagination['limit'] is int
        ? pagination['limit'] as int
        : int.tryParse(pagination['limit']?.toString() ?? '') ?? limit;
    final hasMore = pagination['hasMore'] == true;

    return DoneDeliveriesPage(
      items: items,
      total: total,
      page: currentPage,
      limit: pageLimit,
      hasMore: hasMore,
    );
  }

  return DoneDeliveriesPage(
    items: items,
    total: items.length,
    page: page,
    limit: limit,
    hasMore: false,
  );
}

Future<bool> updateDeliveryIsPaid(int deliveryId, bool isPaid) async {
  final url = Uri.parse('${Url.url}/api/mobile/delivery/$deliveryId/is-paid');
  final response = await http.patch(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'is_paid': isPaid}),
  );

  if (response.statusCode == 200) {
    final jsonResponse = json.decode(response.body);
    return jsonResponse['success'] == true;
  }

  debugPrint('Failed to update is_paid: ${response.statusCode} ${response.body}');
  return false;
}

Color doneStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return const Color(0xFFFF9800);
    case 'хуваарилсан':
      return const Color(0xFF2196F3);
    case 'хүргэсэн':
      return const Color(0xFF4CAF50);
    case 'cancelled':
      return const Color(0xFFF44336);
    default:
      return const Color(0xFFFF9800);
  }
}
