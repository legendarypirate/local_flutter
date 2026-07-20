import 'dart:convert';
import 'dart:io';
import '../app_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../color/color.dart';

/// Merchant-side report — mirrors web `admin/report` when `isMerchant` (role 2):
/// date range → `/api/delivery/findAllWithDate`, selectable deliveries, summary row,
/// Excel-style export (CSV openable in Excel).
class CustomerReport extends StatefulWidget {
  @override
  State<CustomerReport> createState() => _CustomerReportState();
}

class _SummaryRow {
  final String name;
  final int numberDelivery;
  final double totalPrice;
  final double forDriver;

  _SummaryRow({
    required this.name,
    required this.numberDelivery,
    required this.totalPrice,
    required this.forDriver,
  });

  double get zoruu => totalPrice - forDriver;
}

class _CustomerReportState extends State<CustomerReport> {
  static final _dateApi = DateFormat('yyyy-MM-dd');
  static final _dateTimeDisplay = DateFormat('yyyy-MM-dd hh:mm a');
  static final _num0 = NumberFormat.decimalPattern();

  DateTime? _startDate;
  DateTime? _endDate;
  int? _merchantId;

  List<dynamic> _deliveryList = [];
  int _currentPage = 1;
  int _pageSize = 100;
  int _totalCount = 0;
  bool _fetching = false;
  String? _fetchError;

  final Set<int> _selectedIds = {};
  _SummaryRow? _summaryRow;

  @override
  void initState() {
    super.initState();
    _loadMerchantId();
  }

  Future<void> _loadMerchantId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id');
    if (mounted) setState(() => _merchantId = id);
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _toIntStatus(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  int _parseId(dynamic v) => _toIntStatus(v);

  double _getDeliveryPrice(Map<String, dynamic> row) {
    final v = row['delivery_price'];
    if (v == null) return 6000;
    final n = _toDouble(v);
    return n.isNaN ? 6000 : n;
  }

  void _recalculateSummary() {
    if (_merchantId == null) return;
    final selected = _deliveryList
        .where((d) => _selectedIds.contains(_parseId((d as Map)['id'])))
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (selected.isEmpty) {
      setState(() => _summaryRow = null);
      return;
    }

    double totalPrice = 0;
    for (final row in selected) {
      if (_toIntStatus(row['status']) == 3) {
        totalPrice += _toDouble(row['price']);
      }
    }

    double totalFee = 0;
    for (final row in selected) {
      totalFee += _getDeliveryPrice(row);
    }

    final name = (selected.first['merchant'] is Map)
        ? '${(selected.first['merchant'] as Map)['username'] ?? ''}'
        : '';

    setState(() {
      _summaryRow = _SummaryRow(
        name: name,
        numberDelivery: selected.length,
        totalPrice: totalPrice,
        forDriver: totalFee,
      );
    });
  }

  Future<void> _fetchDeliveries() async {
    if (_merchantId == null ||
        _startDate == null ||
        _endDate == null) {
      return;
    }

    setState(() {
      _fetching = true;
      _fetchError = null;
    });

    try {
      final start = _dateApi.format(_startDate!);
      final end = _dateApi.format(_endDate!);
      final uri = Uri.parse(
        '${Url.url}/api/delivery/findAllWithDate'
        '?page=$_currentPage'
        '&limit=$_pageSize'
        '&startDate=$start'
        '&endDate=$end'
        '&merchantId=$_merchantId',
      );

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        throw Exception(body['message']?.toString() ?? 'Амжилтгүй');
      }

      final list = body['data'];
      final data = list is List ? list : <dynamic>[];

      int total = 0;
      final pag = body['pagination'];
      if (pag is Map) {
        total = _toIntStatus(pag['total']);
      }
      if (total == 0 && body['total'] != null) {
        total = _toIntStatus(body['total']);
      }
      if (total == 0 && body['count'] != null) {
        total = _toIntStatus(body['count']);
      }
      if (total == 0) {
        total = data.length;
      }

      if (!mounted) return;
      setState(() {
        _deliveryList = data;
        _totalCount = total;
        _selectedIds.clear();
        _summaryRow = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchError = e.toString();
        _deliveryList = [];
        _totalCount = 0;
        _selectedIds.clear();
        _summaryRow = null;
      });
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
      _deliveryList = [];
      _totalCount = 0;
      _selectedIds.clear();
      _summaryRow = null;
      _fetchError = null;
    });
    if (_startDate != null &&
        _endDate != null &&
        !_startDate!.isAfter(_endDate!)) {
      _currentPage = 1;
      await _fetchDeliveries();
    }
  }

  Future<void> _exportCsv() async {
    if (_deliveryList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Экспортлох өгөгдөл байхгүй байна')),
      );
      return;
    }

    try {
      String esc(String? s) {
        if (s == null || s.isEmpty) return '';
        if (s.contains(',') || s.contains('"') || s.contains('\n')) {
          return '"${s.replaceAll('"', '""')}"';
        }
        return s;
      }

      final buf = StringBuffer();
      buf.writeln(
        'Үүссэн огноо,Хүргэсэн огноо,Мерчанд нэр,Утас,Хаяг,Төлөв,Үнэ,Тайлбар',
      );

      for (final raw in _deliveryList) {
        final d = Map<String, dynamic>.from(raw as Map);
        final created = d['createdAt']?.toString();
        final delivered = d['delivered_at']?.toString();
        String c1 = '-';
        String c2 = '-';
        try {
          if (created != null) {
            c1 = _dateTimeDisplay.format(DateTime.parse(created));
          }
        } catch (_) {}
        try {
          if (delivered != null && delivered.isNotEmpty) {
            c2 = _dateTimeDisplay.format(DateTime.parse(delivered));
          }
        } catch (_) {}

        final merchant = d['merchant'] is Map
            ? '${(d['merchant'] as Map)['username'] ?? ''}'
            : '';
        final status = d['status_name'] is Map
            ? '${(d['status_name'] as Map)['status'] ?? ''}'
            : '';
        final price = _toDouble(d['price']);

        buf.writeln([
          esc(c1),
          esc(c2),
          esc(merchant),
          esc(d['phone']?.toString()),
          esc(d['address']?.toString()),
          esc(status),
          price.toStringAsFixed(0),
          esc(d['comment']?.toString()),
        ].join(','));
      }

      final dir = await getTemporaryDirectory();
      final ts = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final file = File('${dir.path}/delivery_report_$ts.csv');
      await file.writeAsString('\uFEFF${buf.toString()}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV хадгалагдлаа: ${file.path}'),
          action: SnackBarAction(
            label: 'Хуулах',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: file.path));
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Экспортлоход алдаа: $e')),
      );
    }
  }

  int get _totalPages {
    if (_totalCount <= 0) return 1;
    return ((_totalCount - 1) ~/ _pageSize) + 1;
  }

  Widget _chipStatus(Map<String, dynamic> d) {
    final sn = d['status_name'];
    if (sn is! Map) {
      return Text('-', style: appText(fontSize: 12));
    }
    final text = sn['status']?.toString() ?? '-';
    final colorStr = sn['color']?.toString() ?? '#1890ff';
    Color bg;
    try {
      var hex = colorStr.replaceAll('#', '');
      if (hex.length == 6) {
        bg = Color(int.parse('FF$hex', radix: 16));
      } else {
        bg = Colors.blue;
      }
    } catch (_) {
      bg = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bg.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: appText(
          fontSize: 12,
          color: bg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _fmtDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      return _dateTimeDisplay.format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Тайлан нийлэх',
          style: appText(color: Colors.white, fontSize: 15),
        ),
        backgroundColor: primary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filters (merchant: date range only — same effective UI as web isMerchant)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _startDate != null
                          ? _dateApi.format(_startDate!)
                          : 'Эхлэх огноо',
                      style: appText(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('—', style: appText()),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _endDate != null
                          ? _dateApi.format(_endDate!)
                          : 'Дуусах огноо',
                      style: appText(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Toolbar: Excel (web: Excel татах; merchant has no "Тайлан нийлэх" button)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _deliveryList.isEmpty ? null : () => _exportCsv(),
                  icon: const Icon(Icons.download_outlined, size: 20),
                  label: Text('Excel татах', style: appText()),
                ),
                if (_fetchError != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _fetchError!,
                      style: appText(fontSize: 12, color: Colors.red),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Summary table (same columns as web merchant summaryColumns)
          Container(
            color: Colors.white,
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.all(12),
            child: _summaryRow == null
                ? Text(
                    'Тайлан байхгүй байна',
                    style: appText(color: Colors.grey[600]),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          MaterialStateProperty.all(Colors.grey.shade100),
                      columns: [
                        DataColumn(
                          label: Text('нэр',
                              style: appText(
                                  fontWeight: FontWeight.bold)),
                        ),
                        DataColumn(
                          label: Text('Нийт хүргэлт',
                              style: appText(
                                  fontWeight: FontWeight.bold)),
                        ),
                        DataColumn(
                          label: Text('Нийт үнэ',
                              style: appText(
                                  fontWeight: FontWeight.bold)),
                        ),
                        DataColumn(
                          label: Text('Компанид олгох',
                              style: appText(
                                  fontWeight: FontWeight.bold)),
                        ),
                        DataColumn(
                          label: Text('Зөрүү',
                              style: appText(
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                      rows: [
                        DataRow(
                          cells: [
                            DataCell(Text(_summaryRow!.name,
                                style: appText())),
                            DataCell(Text(
                              _num0.format(_summaryRow!.numberDelivery),
                              style: appText(),
                            )),
                            DataCell(Text(
                              '${_num0.format(_summaryRow!.totalPrice.round())} ₮',
                              style: appText(),
                            )),
                            DataCell(Text(
                              '${_num0.format(_summaryRow!.forDriver.round())} ₮',
                              style: appText(),
                            )),
                            DataCell(Text(
                              '${_num0.format(_summaryRow!.zoruu.round())} ₮',
                              style: appText(),
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),

          const Divider(height: 1),

          // Delivery list + pagination
          Expanded(
            child: _merchantId == null
                ? Center(
                    child: Text(
                      'Хэрэглэгчийн мэдээлэл олдсонгүй',
                      style: appText(),
                    ),
                  )
                : _fetching && _deliveryList.isEmpty
                    ? Center(child: CircularProgressIndicator(color: primary))
                    : Column(
                        children: [
                          Expanded(
                            child: _deliveryList.isEmpty
                                ? Center(
                                    child: Text(
                                      _startDate != null && _endDate != null
                                          ? 'Хүргэлт олдсонгүй'
                                          : 'Эхлэх болон дуусах огноо сонгоно уу',
                                      style: appText(
                                          color: Colors.grey[600]),
                                    ),
                                  )
                                : ListView(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    children: [
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          showCheckboxColumn: true,
                                          onSelectAll: (selected) {
                                            setState(() {
                                              if (selected == true) {
                                                for (final d
                                                    in _deliveryList) {
                                                  _selectedIds.add(_parseId(
                                                      (d as Map)['id']));
                                                }
                                              } else {
                                                for (final d
                                                    in _deliveryList) {
                                                  _selectedIds.remove(_parseId(
                                                      (d as Map)['id']));
                                                }
                                              }
                                            });
                                            _recalculateSummary();
                                          },
                                          columnSpacing: 16,
                                          headingRowColor:
                                              MaterialStateProperty.all(
                                                  Colors.grey.shade200),
                                          columns: [
                                            DataColumn(
                                              label: Text('Үүссэн огноо',
                                                  style: appText(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11)),
                                            ),
                                            DataColumn(
                                              label: Text('Хүргэсэн огноо',
                                                  style: appText(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11)),
                                            ),
                                            DataColumn(
                                              label: Text('Утас',
                                                  style: appText(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11)),
                                            ),
                                            DataColumn(
                                              label: Text('Хаяг',
                                                  style: appText(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11)),
                                            ),
                                            DataColumn(
                                              label: Text('Төлөв',
                                                  style: appText(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11)),
                                            ),
                                            DataColumn(
                                              label: Text('Үнэ',
                                                  style: appText(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11)),
                                            ),
                                            DataColumn(
                                              label: Text('Тайлбар',
                                                  style: appText(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11)),
                                            ),
                                          ],
                                          rows: _deliveryList.map((raw) {
                                            final d =
                                                Map<String, dynamic>.from(
                                                    raw as Map);
                                            final id = _parseId(d['id']);
                                            final sel =
                                                _selectedIds.contains(id);
                                            return DataRow(
                                              selected: sel,
                                              onSelectChanged: (v) {
                                                setState(() {
                                                  if (v == true) {
                                                    _selectedIds.add(id);
                                                  } else {
                                                    _selectedIds.remove(id);
                                                  }
                                                });
                                                _recalculateSummary();
                                              },
                                              cells: [
                                                DataCell(Text(
                                                    _fmtDateTime(
                                                        d['createdAt']
                                                            ?.toString()),
                                                    style: appText(
                                                        fontSize: 11))),
                                                DataCell(Text(
                                                    _fmtDateTime(
                                                        d['delivered_at']
                                                            ?.toString()),
                                                    style: appText(
                                                        fontSize: 11))),
                                                DataCell(Text(
                                                    d['phone']?.toString() ??
                                                        '-',
                                                    style: appText(
                                                        fontSize: 11))),
                                                DataCell(SizedBox(
                                                  width: 140,
                                                  child: Text(
                                                    d['address']
                                                            ?.toString() ??
                                                        '-',
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: appText(
                                                        fontSize: 11),
                                                  ),
                                                )),
                                                DataCell(_chipStatus(d)),
                                                DataCell(Text(
                                                  '${_toDouble(d['price']).toStringAsFixed(0)} ₮',
                                                  style: appText(
                                                      fontSize: 11),
                                                )),
                                                DataCell(SizedBox(
                                                  width: 100,
                                                  child: Text(
                                                    d['comment']
                                                            ?.toString() ??
                                                        '-',
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: appText(
                                                        fontSize: 11),
                                                  ),
                                                )),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          if (_totalCount > 0)
                            Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: _currentPage > 1 && !_fetching
                                        ? () {
                                            setState(
                                                () => _currentPage -= 1);
                                            _fetchDeliveries();
                                          }
                                        : null,
                                  ),
                                  Text(
                                    '$_currentPage / $_totalPages (нийт $_totalCount)',
                                    style: appText(fontSize: 13),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: _currentPage < _totalPages &&
                                            !_fetching
                                        ? () {
                                            setState(
                                                () => _currentPage += 1);
                                            _fetchDeliveries();
                                          }
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  DropdownButton<int>(
                                    value: _pageSize,
                                    items: const [
                                      50,
                                      100,
                                      200,
                                      1000,
                                    ].map((s) {
                                      return DropdownMenuItem(
                                        value: s,
                                        child: Text('$s / хуудас'),
                                      );
                                    }).toList(),
                                    onChanged: _fetching
                                        ? null
                                        : (v) {
                                            if (v == null) return;
                                            setState(() {
                                              _pageSize = v;
                                              _currentPage = 1;
                                            });
                                            _fetchDeliveries();
                                          },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
