import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_upload_utils.dart';
import 'dart:convert';
import '../app_text.dart';

import '../color/color.dart';
import 'good_request_tab.dart';

class GoodListScreen extends StatefulWidget {
  @override
  _GoodListScreenState createState() => _GoodListScreenState();
}

class _GoodListScreenState extends State<GoodListScreen> {
  int _warehouseTabIndex = 0;
  int? _merchantId;
  List<dynamic> goods = [];
  List<dynamic> wares = [];
  bool _booting = true;
  bool isLoadingGoods = true;
  int? _uploadingGoodId;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _merchantId = prefs.getInt('user_id');
    await Future.wait([fetchGoods(), fetchWares()]);
    if (mounted) setState(() => _booting = false);
  }

  Future<void> fetchWares() async {
    try {
      final response = await http.get(Uri.parse('${Url.url}/api/ware'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = json.decode(response.body);
        if (jsonBody['success'] == true && mounted) {
          setState(() => wares = jsonBody['data'] ?? []);
        }
      }
    } catch (e) {
      debugPrint('Error fetching wares: $e');
    }
  }

  Future<void> fetchGoods() async {
    if (_merchantId == null) {
      if (mounted) setState(() => isLoadingGoods = false);
      return;
    }
    if (mounted) setState(() => isLoadingGoods = true);
    try {
      final response = await http.get(
        Uri.parse(
            '${Url.url}/api/mobile/good/merchant?user_id=$_merchantId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = json.decode(response.body);
        if (jsonBody['success'] == true && mounted) {
          setState(() {
            goods = jsonBody['data'] ?? [];
            isLoadingGoods = false;
          });
          return;
        }
      }
      if (mounted) setState(() => isLoadingGoods = false);
    } catch (e) {
      if (mounted) setState(() => isLoadingGoods = false);
      debugPrint('Error fetching goods: $e');
    }
  }

  Future<void> _pickAndUploadGoodImage(int goodId, ImageSource source) async {
    if (_merchantId == null) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      final uploadFile =
          await ImageUploadUtils.compressForUpload(File(picked.path)) ??
              File(picked.path);

      setState(() => _uploadingGoodId = goodId);

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('${Url.url}/api/mobile/good/$goodId/image'),
      );
      request.fields['merchant_user_id'] = _merchantId.toString();
      request.files.add(
        await http.MultipartFile.fromPath('image', uploadFile.path),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 90),
      );
      final body = await response.stream.bytesToString();

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonBody = json.decode(body);
        if (jsonBody['success'] == true) {
          await fetchGoods();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Зураг хадгалагдлаа')),
          );
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Зураг хадгалахад алдаа гарлаа')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Зураг илгээхэд алдаа: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingGoodId = null);
    }
  }

  void _showImagePickerSheet(int goodId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text('Камераар авах', style: appText()),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadGoodImage(goodId, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text('Зургийн сангаас сонгох', style: appText()),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadGoodImage(goodId, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoodLeading(dynamic item) {
    final url = item['image_url']?.toString();
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CircleAvatar(
            backgroundColor: Colors.deepOrange.withOpacity(0.2),
            child: Icon(Icons.shopping_basket, color: AppColors.primaryColor),
          ),
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: Colors.deepOrange.withOpacity(0.2),
      child: Icon(Icons.shopping_basket, color: AppColors.primaryColor),
    );
  }

  Widget _buildGoodsTab() {
    final primary = AppColors.primaryColor;
    if (isLoadingGoods) {
      return Center(child: CircularProgressIndicator(color: primary));
    }
    if (goods.isEmpty) {
      return Center(
        child: Text(
          'Бараа олдсонгүй',
          style: appText(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return RefreshIndicator(
      color: primary,
      onRefresh: fetchGoods,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: goods.length,
        itemBuilder: (context, index) {
          final item = goods[index];
          final goodId = item['id'] as int;
          final isUploading = _uploadingGoodId == goodId;
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
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: _buildGoodLeading(item),
              title: Text(
                item['name'] ?? 'No name',
                style: appText(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                item['image_url'] != null && item['image_url'].toString().isNotEmpty
                    ? 'Зурагтай — солих бол камер дарна уу'
                    : 'Зураг нэмэх бол камер дарна уу',
                style: appText(fontSize: 12, color: Colors.grey),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isUploading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: 'Зураг',
                      icon: const Icon(Icons.camera_alt_outlined),
                      color: AppColors.primaryColor,
                      onPressed: () => _showImagePickerSheet(goodId),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item['stock'] ?? 0} ш',
                      style: appText(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryColor;

    if (_booting) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    if (_merchantId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: primary,
          title: Text('Агуулах',
              style: appText(fontSize: 15, color: Colors.white)),
          centerTitle: true,
        ),
        body: Center(
          child: Text(
            'Хэрэглэгчийн мэдээлэл олдсонгүй. Дахин нэвтэрнэ үү.',
            textAlign: TextAlign.center,
            style: appText(fontSize: 15),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: primary,
        title: Text(
          _warehouseTabIndex == 0
              ? 'Барааны жагсаалт'
              : 'Барааны хүсэлт',
          style: appText(fontSize: 15, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 2,
      ),
      body: IndexedStack(
        index: _warehouseTabIndex,
        children: [
          _buildGoodsTab(),
          GoodRequestBody(
            key: ValueKey('req_$_merchantId'),
            merchantId: _merchantId!,
            goods: goods,
            wares: wares,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _warehouseTabIndex,
        onTap: (i) => setState(() => _warehouseTabIndex = i),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle:
            appText(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: appText(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Бараа',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.request_quote_outlined),
            label: 'Барааны хүсэлт',
          ),
        ],
      ),
    );
  }
}
