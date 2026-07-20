import 'dart:async';
import 'dart:convert';
import '../app_text.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../color/color.dart';

int? _jsonId(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// Stock / good requests — same API as web `admin/good-request`.
class GoodRequestBody extends StatefulWidget {
  final int merchantId;
  final List<dynamic> goods;
  final List<dynamic> wares;

  const GoodRequestBody({
    Key? key,
    required this.merchantId,
    required this.goods,
    required this.wares,
  }) : super(key: key);

  @override
  State<GoodRequestBody> createState() => _GoodRequestBodyState();
}

class _GoodRequestBodyState extends State<GoodRequestBody> {
  List<dynamic> requests = [];
  bool isLoadingRequests = true;

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    if (!mounted) return;
    setState(() => isLoadingRequests = true);
    try {
      final response = await http.get(
        Uri.parse('${Url.url}/api/request?merchant_id=${widget.merchantId}'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = json.decode(response.body);
        if (jsonBody['success'] == true && mounted) {
          setState(() {
            requests = jsonBody['data'] ?? [];
            isLoadingRequests = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => isLoadingRequests = false);
  }

  String _getStatusText(int status) {
    switch (status) {
      case 1:
        return 'Хүлээгдэж байна';
      case 2:
        return 'Зөвшөөрөгдсөн';
      case 3:
        return 'Татгалзсан';
      default:
        return 'Тодорхойгүй';
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTypeText(int type) {
    switch (type) {
      case 1:
        return 'Шинэ бараа үүсгэх';
      case 2:
        return 'Нэмэх';
      case 3:
        return 'Хасах';
      default:
        return 'Тодорхойгүй';
    }
  }

  void openCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RequestFormSheetContent(
        merchantId: widget.merchantId,
        goods: widget.goods,
        wares: widget.wares,
        onSuccess: () {
          fetchRequests();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryColor;

    if (isLoadingRequests) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      floatingActionButton: FloatingActionButton(
        onPressed: openCreateSheet,
        backgroundColor: primary,
        tooltip: 'Хүсэлт үүсгэх',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
      color: primary,
      onRefresh: fetchRequests,
      child: requests.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                Center(
                  child: Text(
                    'Хүсэлт байхгүй.\n+ товчоор шинэ хүсэлт үүсгэнэ үү.',
                    textAlign: TextAlign.center,
                    style: appText(fontSize: 15, color: Colors.grey[600]),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                final status = request['status'] ?? 0;
                final type = request['type'] ?? 0;
                final goodName = request['good']?['name'] ??
                    request['name'] ??
                    'Тодорхойгүй';
                final wareName = request['ware']?['name'] ?? 'Тодорхойгүй';
                final stock = request['stock'] ?? 0;
                final approvedStock = request['approved_stock'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: CircleAvatar(
                      backgroundColor:
                          _getStatusColor(status).withOpacity(0.2),
                      child: Icon(Icons.request_quote,
                          color: _getStatusColor(status)),
                    ),
                    title: Text(
                      goodName,
                      style: appText(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Агуулах: $wareName',
                          style: appText(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                        Text(
                          'Төрөл: ${_getTypeText(type)}',
                          style: appText(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (approvedStock != null)
                          Text(
                            'Зөвшөөрсөн: $approvedStock ш',
                            style: appText(
                                fontSize: 12, color: Colors.green[700]),
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getStatusText(status),
                            style: appText(
                                color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            '$stock ш',
                            style: appText(
                                color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}

class _RequestFormSheetContent extends StatefulWidget {
  final int merchantId;
  final List<dynamic> goods;
  final List<dynamic> wares;
  final VoidCallback onSuccess;

  const _RequestFormSheetContent({
    required this.merchantId,
    required this.goods,
    required this.wares,
    required this.onSuccess,
  });

  @override
  State<_RequestFormSheetContent> createState() =>
      _RequestFormSheetContentState();
}

class _RequestFormSheetContentState extends State<_RequestFormSheetContent> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  int _selectedType = 2;
  int? _selectedWareId;
  int? _selectedGoodId;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredGoods {
    if (_selectedWareId == null) return [];
    return widget.goods
        .where((good) =>
            good['ware_id'] == _selectedWareId ||
            good['ware']?['id'] == _selectedWareId)
        .toList();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тоо ширхэг 0-ээс их байх ёстой')),
      );
      return;
    }
    if (_selectedWareId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Агуулах сонгоно уу'),
            backgroundColor: Colors.red.shade700),
      );
      return;
    }
    if (_selectedType == 1) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Барааны нэр оруулна уу'),
              backgroundColor: Colors.red.shade700),
        );
        return;
      }
    } else {
      if (_selectedGoodId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Бараа сонгоно уу'),
              backgroundColor: Colors.red.shade700),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    final Map<String, dynamic> payload = {
      'type': _selectedType,
      'amount': amount,
      'ware_id': _selectedWareId,
      'merchant_id': widget.merchantId,
    };
    if (_selectedType == 1) {
      payload['name'] = _nameController.text.trim();
    } else {
      payload['good_id'] = _selectedGoodId;
    }

    try {
      final response = await http
          .post(
            Uri.parse('${Url.url}/api/request/stock'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('timeout'),
          );

      Map<String, dynamic>? resBody;
      try {
        resBody = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {}

      final ok = (response.statusCode == 200 || response.statusCode == 201) &&
          (resBody == null || resBody['success'] == true);

      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Хүсэлт амжилттай үүсгэгдлээ'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        widget.onSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resBody?['message']?.toString() ??
                  'Хүсэлт үүсгэхэд алдаа гарлаа (${response.statusCode})',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Холболт удаан байна. Дахин оролдоно уу.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppColors.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom + 16,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Хүсэлт үүсгэх',
                style: appText(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Төрөл, агуулах, бараа (эсвэл шинэ нэр), тоо',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Text('Хүсэлтийн төрөл',
                  style: appText(
                      fontWeight: FontWeight.w600, color: primary)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                          value: 1, child: Text('Шинэ бараа үүсгэх')),
                      DropdownMenuItem(value: 2, child: Text('Нэмэх')),
                      DropdownMenuItem(value: 3, child: Text('Хасах')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _selectedType = v;
                        _selectedGoodId = null;
                        _nameController.clear();
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Агуулах',
                  style: appText(
                      fontWeight: FontWeight.w600, color: primary)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedWareId,
                    isExpanded: true,
                    hint: const Text('Агуулах сонгох'),
                    items: [
                      for (final ware in widget.wares)
                        if (_jsonId(ware['id']) != null)
                          DropdownMenuItem<int>(
                            value: _jsonId(ware['id'])!,
                            child: Text(ware['name']?.toString() ?? '—'),
                          ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedWareId = v;
                        _selectedGoodId = null;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedType == 1) ...[
                Text('Шинэ барааны нэр',
                    style: appText(
                        fontWeight: FontWeight.w600, color: primary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Барааны нэр',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else ...[
                Text('Бараа',
                    style: appText(
                        fontWeight: FontWeight.w600, color: primary)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedGoodId,
                      isExpanded: true,
                      hint: const Text('Бараа сонгох'),
                      items: [
                        for (final good in _filteredGoods)
                          if (_jsonId(good['id']) != null)
                            DropdownMenuItem<int>(
                              value: _jsonId(good['id'])!,
                              child: Text(
                                  '${good['name']} (${good['stock'] ?? 0})'),
                            ),
                      ],
                      onChanged: (_selectedWareId == null ||
                              _filteredGoods.isEmpty)
                          ? null
                          : (v) => setState(() => _selectedGoodId = v),
                    ),
                  ),
                ),
                if (_selectedWareId != null && _filteredGoods.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Энэ агуулахад бараа байхгүй байна',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Text('Тоо ширхэг',
                  style: appText(
                      fontWeight: FontWeight.w600, color: primary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  hintText: 'Тоо',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Тоо оруулна уу';
                  if (int.tryParse(v) == null) return 'Тоо зөв оруулна уу';
                  if (int.parse(v) <= 0) return '0-ээс их байх ёстой';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Цуцлах'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Илгээх'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
