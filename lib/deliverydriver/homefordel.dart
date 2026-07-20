import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../app_text.dart';

import '../color/color.dart';

class SummaryScreen extends StatefulWidget {
  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  DateTime? startDate;
  DateTime? endDate;

  final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
  Map<String, Map<String, dynamic>> dailyData = {};
  Set<String> selectedDates = {};
  bool loading = false;
  int? driverId;

  @override
  void initState() {
    super.initState();
    _loadDriverId();
  }

  Future<void> _loadDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      driverId = prefs.getInt('user_id');
    });
  }

  Future<void> fetchReport() async {
    if (startDate == null || endDate == null || driverId == null) return;

    setState(() => loading = true);

    final start = dateFormat.format(startDate!);
    final end = dateFormat.format(endDate!);
    final reportUrl = Uri.parse(
      '${Url.url}/api/mobile/delivery/report?driver_id=$driverId&start_date=$start&end_date=$end',
    );

    try {
      final res = await http.get(reportUrl);
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      final Map<String, Map<String, dynamic>> parsedData = {};
      final List<Map<String, dynamic>> syncDays = [];

      for (var item in data['data']) {
        final totalDeliveries = _toInt(item['total_deliveries']);
        final deliveredCount = _toInt(item['delivered_count']);
        final addressVisitCount = _toInt(item['address_visit_count']);
        final totalAmount = _toInt(item['delivered_total_price']);
        final driverSalary = _toInt(item['for_driver']);
        final difference = _toInt(item['driver_margin']);
        final day = item['date']?.toString() ?? '';

        parsedData[day] = {
          'totalDelivery': totalDeliveries,
          'deliveredDelivery': deliveredCount,
          'addressVisit': addressVisitCount,
          'totalAmount': totalAmount,
          'driverSalary': driverSalary,
          'difference': difference,
          'amountPaid': 0,
          'remaining': totalAmount,
          'payments': <dynamic>[],
        };

        syncDays.add({
          'date': day,
          'total_amount': totalAmount,
          'driver_salary': driverSalary,
          'difference': difference,
          'delivery_count': deliveredCount + addressVisitCount,
        });
      }

      await http.post(
        Uri.parse('${Url.url}/api/mobile/delivery/daily-settlements/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'driver_id': driverId, 'days': syncDays}),
      );

      final settRes = await http.get(
        Uri.parse(
          '${Url.url}/api/mobile/delivery/daily-settlements?driver_id=$driverId&start_date=$start&end_date=$end',
        ),
      );

      if (settRes.statusCode == 200) {
        final settJson = jsonDecode(settRes.body);
        if (settJson['success'] == true && settJson['data'] is List) {
          for (final s in settJson['data']) {
            final day = s['settlement_date']?.toString() ?? '';
            if (!parsedData.containsKey(day)) {
              parsedData[day] = {
                'totalDelivery': 0,
                'deliveredDelivery': 0,
                'addressVisit': 0,
                'totalAmount': _toInt(s['total_amount']),
                'driverSalary': _toInt(s['driver_salary']),
                'difference': _toInt(s['difference']),
                'amountPaid': 0,
                'remaining': _toInt(s['total_amount']),
                'payments': <dynamic>[],
              };
            }
            parsedData[day]!['amountPaid'] = _toInt(s['amount_paid']);
            parsedData[day]!['remaining'] = _toInt(s['remaining']);
            parsedData[day]!['payments'] = s['payments'] ?? [];
            parsedData[day]!['settlementId'] = s['id'];
          }
        }
      }

      setState(() {
        dailyData = parsedData;
      });
    } catch (e) {
      debugPrint('fetchReport error: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  Future<void> pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        startDate = picked;
        selectedDates.clear();
        if (endDate != null && endDate!.isBefore(startDate!)) {
          endDate = null;
          dailyData.clear();
        }
      });
      if (endDate != null) await fetchReport();
    }
  }

  Future<void> pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now(),
      firstDate: startDate ?? DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        endDate = picked;
        selectedDates.clear();
      });
      if (startDate != null) await fetchReport();
    }
  }

  Map<String, int> calculateSelectedTotals() {
    final totals = {
      'totalDelivery': 0,
      'deliveredDelivery': 0,
      'addressVisit': 0,
      'totalAmount': 0,
      'driverSalary': 0,
      'difference': 0,
      'amountPaid': 0,
      'remaining': 0,
    };

    final datesToSum = selectedDates.isEmpty ? dailyData.keys : selectedDates;
    for (var date in datesToSum) {
      final stats = dailyData[date];
      if (stats != null) {
        totals['totalDelivery'] = totals['totalDelivery']! + _toInt(stats['totalDelivery']);
        totals['deliveredDelivery'] = totals['deliveredDelivery']! + _toInt(stats['deliveredDelivery']);
        totals['addressVisit'] = totals['addressVisit']! + _toInt(stats['addressVisit']);
        totals['totalAmount'] = totals['totalAmount']! + _toInt(stats['totalAmount']);
        totals['driverSalary'] = totals['driverSalary']! + _toInt(stats['driverSalary']);
        totals['difference'] = totals['difference']! + _toInt(stats['difference']);
        totals['amountPaid'] = totals['amountPaid']! + _toInt(stats['amountPaid']);
      }
    }

    // Үлдэгдэл = нийт төлөх ёстой − төлсөн (төлөөгүй дүнгийн нийлбэр)
    final unpaid = totals['totalAmount']! - totals['amountPaid']!;
    totals['remaining'] = unpaid > 0 ? unpaid : 0;

    return totals;
  }

  String _paymentStatusLabel(int totalAmount, int amountPaid, int remaining) {
    if (totalAmount <= 0) return '—';
    if (remaining <= 0) return 'Төлсөн';
    if (amountPaid > 0) return 'Хэсэгчлэн';
    return 'Төлөөгүй';
  }

  @override
  Widget build(BuildContext context) {
    final totals = calculateSelectedTotals();
    final sortedDays = dailyData.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Нийт мэдээлэл', style: appText(color: Colors.white, fontSize: 15)),
        backgroundColor: const Color(0xFF0e0e6e),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: pickStartDate,
                    child: Text(
                      startDate != null ? 'Start: ${dateFormat.format(startDate!)}' : 'Start Date',
                      style: appText(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: startDate == null ? null : pickEndDate,
                    child: Text(
                      endDate != null ? 'End: ${dateFormat.format(endDate!)}' : 'End Date',
                      style: appText(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (startDate != null && endDate != null && dailyData.isNotEmpty)
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 40,
                          dataRowMinHeight: 44,
                          dataRowMaxHeight: 56,
                          columns: [
                            _col('Огноо'),
                            _col('Дүн'),
                            _col('Төлсөн'),
                            _col('Үлдэгдэл'),
                            _col('Ж/олгох'),
                            _col('Зөрүү'),
                            _col('Төлөв'),
                          ],
                          rows: sortedDays.map((day) {
                            final stats = dailyData[day]!;
                            final remaining = _toInt(stats['remaining']);
                            final paid = remaining <= 0 && _toInt(stats['totalAmount']) > 0;
                            return DataRow(
                              color: paid
                                  ? MaterialStateProperty.all(Colors.green.shade50)
                                  : null,
                              cells: [
                                DataCell(Text(day, style: appText(fontSize: 11))),
                                DataCell(Text('${_toInt(stats['totalAmount'])}₮', style: appText(fontSize: 11))),
                                DataCell(Text('${_toInt(stats['amountPaid'])}₮', style: appText(fontSize: 11))),
                                DataCell(
                                  Text(
                                    '${remaining}₮',
                                    style: appText(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: remaining > 0 ? Colors.red : Colors.green,
                                    ),
                                  ),
                                ),
                                DataCell(Text('${_toInt(stats['driverSalary'])}₮', style: appText(fontSize: 11))),
                                DataCell(Text('${_toInt(stats['difference'])}₮', style: appText(fontSize: 11))),
                                DataCell(
                                  Text(
                                    _paymentStatusLabel(
                                      _toInt(stats['totalAmount']),
                                      _toInt(stats['amountPaid']),
                                      remaining,
                                    ),
                                    style: appText(
                                      fontSize: 11,
                                      color: remaining > 0 && _toInt(stats['amountPaid']) == 0
                                          ? Colors.red
                                          : remaining <= 0 && _toInt(stats['totalAmount']) > 0
                                              ? Colors.green
                                              : Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: Column(
                      children: [
                        Text(
                          selectedDates.isEmpty
                              ? 'Бүх өдрийн нийлбэр'
                              : 'Сонгосон ${selectedDates.length} өдөр',
                          style: appText(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildAmountContainer('Дүн (төлөх)', totals['totalAmount']!, Colors.blue.shade100),
                            _buildAmountContainer('Жолоочид олгох', totals['driverSalary']!, Colors.green.shade100),
                            _buildAmountContainer('Үлдэгдэл', totals['remaining']!, Colors.orange.shade100),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Center(
                child: Text('Өдөр сонгоно уу', style: appText(fontSize: 16, color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }

  DataColumn _col(String label) {
    return DataColumn(label: Text(label, style: appText(fontWeight: FontWeight.bold, fontSize: 11)));
  }

  Widget _buildAmountContainer(String label, int amount, Color bgColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: appText(fontWeight: FontWeight.w600, fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('${amount}₮', style: appText(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
