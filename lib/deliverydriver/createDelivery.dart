import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_text.dart';
import '../color/color.dart';

String normalizeDeliveryPhone(String raw) {
  return raw.replaceAll(RegExp(r'\D'), '');
}

class _DecimalNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var t = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');
    final dot = t.indexOf('.');
    if (dot != -1) {
      t = t.substring(0, dot + 1) + t.substring(dot + 1).replaceAll('.', '');
    }
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}

class CreateDelivery extends StatefulWidget {
  const CreateDelivery({Key? key}) : super(key: key);

  @override
  State<CreateDelivery> createState() => _CreateDeliveryState();
}

class _CreateDeliveryState extends State<CreateDelivery> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  static const _primary = Color(0xFF0e0e6e);

  bool _loadGoods = false;
  List<dynamic> _goods = [];
  List<Map<String, dynamic>> _cartItems = [];
  List<Map<String, dynamic>> _districts = [];
  bool _loadingDistricts = false;
  int? _selectedDistrictId;
  int? _selectedKhorooId;
  bool _isSubmitting = false;
  bool _isPaid = false;
  bool _isRural = false;
  List<Map<String, dynamic>> _khoroos = [];
  Map<int, int> _khorooIdByNumber = {};
  bool _loadingKhoroos = false;
  static const int _khorooMin = 1;
  static const int _khorooMax = 50;
  String? _assignmentRegionName;
  String? _assignmentDriverName;

  @override
  void initState() {
    super.initState();
    _fetchDistricts();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _commentController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _fetchDistricts() async {
    setState(() => _loadingDistricts = true);
    try {
      final res = await http.get(Uri.parse('${Url.url}/api/region'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          setState(() {
            _districts = List<Map<String, dynamic>>.from(body['data'] ?? []);
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  Future<void> _fetchKhoroos(int regionId) async {
    setState(() {
      _loadingKhoroos = true;
      _khoroos = [];
      _selectedKhorooId = null;
      _assignmentRegionName = null;
      _assignmentDriverName = null;
    });
    try {
      final res = await http.get(
        Uri.parse('${Url.url}/api/khoroo?region_id=$regionId'),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final map = <int, int>{};
          for (final k in List<Map<String, dynamic>>.from(body['data'] ?? [])) {
            final n = int.tryParse(k['name']?.toString() ?? '');
            final id = k['id'] as int?;
            if (n != null && n >= _khorooMin && n <= _khorooMax && id != null && !map.containsKey(n)) {
              map[n] = id;
            }
          }
          setState(() {
            _khorooIdByNumber = map;
            _khoroos = map.entries
                .map((e) => {'id': e.value, 'name': '${e.key}'})
                .toList()
              ..sort((a, b) => int.parse(a['name'] as String).compareTo(int.parse(b['name'] as String)));
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingKhoroos = false);
    }
  }

  Future<void> _refreshAssignmentPreview() async {
    if (!_isRural && _selectedKhorooId == null) {
      setState(() {
        _assignmentRegionName = null;
        _assignmentDriverName = null;
      });
      return;
    }
    try {
      final q = _isRural
          ? 'is_rural=true'
          : 'khoroo_id=$_selectedKhorooId';
      final res = await http.get(
        Uri.parse('${Url.url}/api/service-region/lookup?$q'),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final d = body['data'];
          setState(() {
            _assignmentRegionName = d['service_region_name']?.toString();
            _assignmentDriverName = d['driver_username']?.toString();
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _assignmentRegionName = null;
        _assignmentDriverName = null;
      });
    }
  }

  void _setRural(bool value) {
    setState(() {
      _isRural = value;
      if (value) {
        _selectedDistrictId = null;
        _selectedKhorooId = null;
        _khoroos = [];
      }
    });
    _refreshAssignmentPreview();
  }

  Future<void> _fetchGoods(int merchantId) async {
    final res = await http.get(Uri.parse('${Url.url}/api/good?merchant_id=$merchantId'));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true) {
        setState(() => _goods = body['data']);
      }
    }
  }

  double calculateTotalPrice() {
    return _cartItems.fold(0.0, (sum, item) => sum + (item['unit_price'] * item['quantity']));
  }

  void _handleIsPaidChange(bool? value) {
    setState(() {
      _isPaid = value ?? false;
      if (_isPaid) {
        _priceController.text = '0';
      }
    });
  }

  Future<void> _saveDelivery() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (!_isRural) {
      if (_selectedDistrictId == null) {
        _snack('Дүүрэг сонгоно уу!', Colors.orange);
        return;
      }
      if (_selectedKhorooId == null) {
        _snack('Хороо сонгоно уу (эсвэл Орон нутаг сонгоно уу).', Colors.orange);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final merchantId = prefs.getInt('user_id');

      double? latitude;
      double? longitude;
      final addressText = _addressController.text.trim();
      if (addressText.isNotEmpty) {
        try {
          final geoRes = await http.post(
            Uri.parse('${Url.url}/api/delivery/geocode'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'address': addressText}),
          );
          if (geoRes.statusCode == 200) {
            final geoJson = jsonDecode(geoRes.body);
            if (geoJson['success'] == true && geoJson['data'] != null) {
              final d = geoJson['data'];
              latitude = (d['latitude'] as num?)?.toDouble();
              longitude = (d['longitude'] as num?)?.toDouble();
            }
          }
        } catch (_) {}
      }

      final payload = {
        'merchant_id': merchantId,
        'phone': normalizeDeliveryPhone(_phoneController.text),
        'address': addressText,
        'dist_id': _isRural ? null : _selectedDistrictId,
        'khoroo_id': _isRural ? null : _selectedKhorooId,
        'is_rural': _isRural,
        'is_paid': _isPaid,
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'comment': _commentController.text.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'items': _cartItems
            .map((e) => {
                  'good_id': e['good_id'],
                  'quantity': e['quantity'],
                })
            .toList(),
      };

      final res = await http
          .post(
            Uri.parse('${Url.url}/api/delivery'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        String okMsg = 'Хүргэлт амжилттай үүслээ!';
        final sra = body['service_region_assignment'];
        if (sra is Map && sra['service_region_name'] != null) {
          okMsg =
              'Амжилттай (Шинэ). «${sra['service_region_name']}» бүсэд орлоо.';
        }
        _snack(okMsg, Colors.green);
        if (mounted) Navigator.pop(context);
      } else {
        final body = jsonDecode(res.body);
        _snack(body['message']?.toString() ?? 'Алдаа гарлаа', Colors.red);
      }
    } catch (e) {
      _snack('Сүлжээний алдаа: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String text, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: appText()), backgroundColor: bg),
    );
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: appText(),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _primary, size: 22),
                const SizedBox(width: 8),
                Text(title, style: appText(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget? _assignmentBanner() {
    if (_assignmentRegionName == null) return null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9FA8DA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_shipping_outlined, color: _primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Бүс: $_assignmentRegionName', style: appText(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Хадгалахад энэ бүсэд орно (Шинэ). Жолоочийг админ онооно.',
                  style: appText(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoodsCard() {
    return Column(
      children: _goods.map((good) {
        final pricePerUnitController = TextEditingController();
        final quantityController = TextEditingController(text: '1');

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(good['name'], style: appText(fontWeight: FontWeight.bold)),
                    ),
                    Text(
                      'Үлдэгдэл: ${good['stock'] ?? 0}',
                      style: appText(
                        color: (good['stock'] ?? 0) > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pricePerUnitController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [_DecimalNumberInputFormatter()],
                        decoration: _fieldDecoration('Нэгж үнэ'),
                        style: appText(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _fieldDecoration('Тоо'),
                        style: appText(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () {
                        final unitPrice = double.tryParse(pricePerUnitController.text) ?? 0;
                        final qty = int.tryParse(quantityController.text) ?? 1;
                        if (unitPrice <= 0 || qty <= 0) {
                          _snack('Үнэ болон тоо ширхэг оруулна уу', Colors.orange);
                          return;
                        }
                        final currentStock = good['stock'] ?? 0;
                        final existingQuantity = _cartItems
                            .where((item) => item['good_id'] == good['id'])
                            .fold<int>(0, (sum, item) => sum + ((item['quantity'] as int?) ?? 0));
                        final totalQuantityNeeded = existingQuantity + qty;
                        if (totalQuantityNeeded > currentStock) {
                          _snack(
                            'Үлдэгдэл хүрэлцэхгүй! Боломжтой: $currentStock',
                            Colors.red,
                          );
                          return;
                        }
                        setState(() {
                          _cartItems.add({
                            'good_id': good['id'],
                            'quantity': qty,
                            'unit_price': unitPrice,
                          });
                          if (!_isPaid) {
                            _priceController.text =
                                calculateTotalPrice().toStringAsFixed(2);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCartList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Сагс:', style: appText(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ListView.builder(
          itemCount: _cartItems.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final item = _cartItems[index];
            final good = _goods.firstWhere(
              (g) => g['id'] == item['good_id'],
              orElse: () => null,
            );
            return ListTile(
              dense: true,
              leading: const Icon(Icons.inventory_2_outlined, color: Colors.deepOrange),
              title: Text(
                good != null ? good['name'] : 'ID: ${item['good_id']}',
                style: appText(),
              ),
              subtitle: Text(
                '${item['quantity']} × ₮${item['unit_price']}',
                style: appText(fontSize: 12),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Шинэ хүргэлт', style: appText(color: Colors.white, fontSize: 16)),
        backgroundColor: _primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_assignmentBanner() != null) _assignmentBanner()!,
            _sectionCard(
              title: 'Холбоо барих',
              icon: Icons.contact_phone_outlined,
              children: [
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: appText(),
                  decoration: _fieldDecoration('Утас', hint: '99090099'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Утас оруулна уу';
                    if (normalizeDeliveryPhone(v).isEmpty) return 'Утасны дугаар оруулна уу';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  style: appText(),
                  maxLines: 2,
                  decoration: _fieldDecoration('Хаяг'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Хаяг оруулна уу' : null,
                ),
              ],
            ),
            _sectionCard(
              title: 'Байршил',
              icon: Icons.place_outlined,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Орон нутаг', style: appText(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    'Сонговол дүүрэг, хороо шаардлагагүй',
                    style: appText(fontSize: 12, color: Colors.black54),
                  ),
                  value: _isRural,
                  activeColor: _primary,
                  onChanged: _setRural,
                ),
                if (!_isRural) ...[
                  DropdownButtonFormField<int>(
                    value: _selectedDistrictId,
                    decoration: _fieldDecoration('Дүүрэг'),
                    style: appText(color: Colors.black87),
                    items: _districts.map((d) {
                      return DropdownMenuItem<int>(
                        value: d['id'] as int,
                        child: Text(d['name']?.toString() ?? '', style: appText()),
                      );
                    }).toList(),
                    onChanged: _loadingDistricts
                        ? null
                        : (v) {
                            setState(() {
                              _selectedDistrictId = v;
                              _selectedKhorooId = null;
                            });
                            if (v != null) _fetchKhoroos(v);
                          },
                    validator: (v) => _isRural || v != null ? null : 'Дүүрэг сонгоно уу',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _selectedKhorooId,
                    decoration: _fieldDecoration('Хороо'),
                    style: appText(color: Colors.black87),
                    items: List.generate(_khorooMax - _khorooMin + 1, (i) {
                      final num = i + _khorooMin;
                      final id = _khorooIdByNumber[num];
                      if (id == null) return null;
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text('$num-р хороо', style: appText()),
                      );
                    }).whereType<DropdownMenuItem<int>>().toList(),
                    onChanged: _selectedDistrictId == null || _loadingKhoroos
                        ? null
                        : (v) async {
                            setState(() => _selectedKhorooId = v);
                            await _refreshAssignmentPreview();
                          },
                    validator: (v) =>
                        _isRural || v != null ? null : 'Хороо сонгоно уу',
                  ),
                ],
              ],
            ),
            _sectionCard(
              title: 'Төлбөр',
              icon: Icons.payments_outlined,
              children: [
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [_DecimalNumberInputFormatter()],
                  enabled: !_isPaid,
                  style: appText(),
                  decoration: _fieldDecoration('Үнэ (нийт)'),
                  validator: (v) => v == null || v.isEmpty ? 'Үнэ оруулна уу' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _commentController,
                  maxLines: 2,
                  style: appText(),
                  decoration: _fieldDecoration('Тайлбар'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Тооцоо хийсэн', style: appText()),
                  value: _isPaid,
                  activeColor: _primary,
                  onChanged: _handleIsPaidChange,
                ),
              ],
            ),
            _sectionCard(
              title: 'Агуулах',
              icon: Icons.inventory_outlined,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Бараа нэмэх', style: appText()),
                  value: _loadGoods,
                  activeColor: _primary,
                  onChanged: (val) async {
                    setState(() => _loadGoods = val);
                    if (val) {
                      final prefs = await SharedPreferences.getInstance();
                      final merchantId = prefs.getInt('user_id');
                      if (merchantId != null) await _fetchGoods(merchantId);
                    }
                  },
                ),
                if (_loadGoods) _buildGoodsCard(),
                if (_cartItems.isNotEmpty) _buildCartList(),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _saveDelivery,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('Хадгалагдаж байна...', style: appText(color: Colors.white)),
                        ],
                      )
                    : Text('Хадгалах', style: appText(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
