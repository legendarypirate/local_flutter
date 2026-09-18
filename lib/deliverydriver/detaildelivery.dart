import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../color/color.dart';
import '../mainscreen.dart';
import '../utils/image_upload_utils.dart';

/// Text styles without [google_fonts] — avoids AssetManifest.json / runtime font bundle errors.
TextStyle _tx({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
}) =>
    TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );

class DeliveryDetailScreen extends StatefulWidget {
  final int deliveryId;

  DeliveryDetailScreen({required this.deliveryId});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  Map<String, dynamic>? delivery;
  bool isLoading = true;
  bool _isSubmitting = false;
  String? _submittingMessage;
  String? error;
  List<dynamic> items = [];
  List<dynamic> statuses = [];
  int? selectedStatusId;
  TextEditingController commentController = TextEditingController();
  final TextEditingController _newAddressController = TextEditingController();
  File? _pendingProofImage;
  final ImagePicker _imagePicker = ImagePicker();

  bool get _isRural {
    final v = delivery?['is_rural'];
    return v == true || v == 1 || v == '1' || v == 'true';
  }

  bool _statusRequiresImage(int status) {
    return status == 7 || (status == 3 && _isRural);
  }

  Future<File?> _pickProofImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text('Камер', style: _tx()),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('Зургийн цомог', style: _tx()),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return await ImageUploadUtils.compressForUpload(File(picked.path));
  }

  Future<bool> _submitComplete(int status, {String? driverComment, File? imageFile}) async {
    try {
      final url = Uri.parse('${Url.url}/api/mobile/delivery/complete/${delivery!['id']}');
      final request = http.MultipartRequest('POST', url);
      request.fields['status'] = status.toString();
      final comment = driverComment?.trim() ?? '';
      if (comment.isNotEmpty) {
        request.fields['driver_comment'] = comment;
      }
      if (imageFile != null) {
        final uploadFile =
            await ImageUploadUtils.compressForUpload(imageFile) ?? imageFile;
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            uploadFile.path,
            filename: 'delivery_proof.jpg',
          ),
        );
      }

      final streamed = await request.send().timeout(
        Duration(seconds: imageFile != null ? 90 : 30),
        onTimeout: () => throw TimeoutException('upload'),
      );
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode != 200) {
        String err = res.statusCode == 413
            ? 'Зураг хэт том байна. Дахин зураг авна уу.'
            : 'Сервертэй холбогдож чадсангүй';
        try {
          final j = jsonDecode(res.body);
          if (j['message'] != null) err = j['message'].toString();
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
        }
        return false;
      }

      final data = jsonDecode(res.body);
      if (data['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']?.toString() ?? 'Алдаа гарлаа'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
      return true;
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Холболт удаан байна. Интернэтээ шалгаад дахин оролдоно уу.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }


  Future<void> fetchItems() async {
    final url = Uri.parse('${Url.url}/api/delivery/${widget.deliveryId}/items');
    print('🔍 [DEBUG] fetchItems - URL: $url');

    try {
      final response = await http.get(url);
      print('🔍 [DEBUG] fetchItems - Status Code: ${response.statusCode}');
      print('🔍 [DEBUG] fetchItems - Raw Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('🔍 [DEBUG] fetchItems - Parsed JSON: $jsonResponse');
        print('🔍 [DEBUG] fetchItems - Success: ${jsonResponse['success']}');
        
        if (jsonResponse['success'] == true) {
          print('🔍 [DEBUG] fetchItems - Items Data: ${jsonResponse['data']}');
          print('🔍 [DEBUG] fetchItems - Items Count: ${jsonResponse['data']?.length ?? 0}');
          
          // Print each item structure
          if (jsonResponse['data'] != null) {
            for (var i = 0; i < jsonResponse['data'].length; i++) {
              print('🔍 [DEBUG] fetchItems - Item[$i]: ${jsonResponse['data'][i]}');
              print('🔍 [DEBUG] fetchItems - Item[$i] good: ${jsonResponse['data'][i]['good']}');
            }
          }
          
          setState(() {
            items = jsonResponse['data'];
          });
        } else {
          print('🔍 [DEBUG] fetchItems - Failed: ${jsonResponse['message'] ?? 'Unknown error'}');
        }
      } else {
        print('🔍 [DEBUG] fetchItems - Item fetch failed: ${response.statusCode}');
        print('🔍 [DEBUG] fetchItems - Error Body: ${response.body}');
      }
    } catch (e) {
      print('🔍 [DEBUG] fetchItems - Error: $e');
      print('🔍 [DEBUG] fetchItems - Stack Trace: ${StackTrace.current}');
    }
  }

  Future<void> _callPhoneNumber(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Утасны дугаарыг дуудахад алдаа гарлаа')),
      );
    }
  }

  Future<void> _fetchStatuses() async {
    final url = Uri.parse('${Url.url}/api/status');
    print('🔍 [DEBUG] _fetchStatuses - URL: $url');
    
    final res = await http.get(url);
    print('🔍 [DEBUG] _fetchStatuses - Status Code: ${res.statusCode}');
    print('🔍 [DEBUG] _fetchStatuses - Raw Response: ${res.body}');

    if (res.statusCode == 200) {
      final jsonData = jsonDecode(res.body);
      print('🔍 [DEBUG] _fetchStatuses - Parsed JSON: $jsonData');
      print('🔍 [DEBUG] _fetchStatuses - Statuses Data: ${jsonData['data']}');
      statuses = jsonData['data'];
      setState(() {}); // refresh dropdown
    } else {
      print('🔍 [DEBUG] _fetchStatuses - Failed with status: ${res.statusCode}');
      throw Exception('Failed to load statuses');
    }
  }

  Future<bool> _submitPostpone({
    bool showOverlay = true,
    bool navigateOnSuccess = true,
  }) async {
    if (selectedStatusId == null) {
      print('🔍 [DEBUG] _submitPostpone - selectedStatusId is null');
      return false;
    }

    final status = selectedStatusId!;
    File? imageFile = _pendingProofImage;
    if (_statusRequiresImage(status) && imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Зураг оруулна уу'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final message = imageFile != null
        ? 'Зураг илгээж байна...'
        : 'Хадгалагдаж байна...';

    setState(() {
      _isSubmitting = true;
      _submittingMessage = showOverlay ? message : null;
    });

    try {
      final ok = await _submitComplete(
        status,
        driverComment: commentController.text,
        imageFile: imageFile,
      );
      if (!ok) return false;

      _pendingProofImage = null;
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Төлөв амжилттай шинэчлэгдлээ')),
      );
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (navigateOnSuccess && userId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MainScreen(id: userId)),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingMessage = null;
        });
      }
    }
  }

  Future<void> _beginStatusFlow(int status) async {
    selectedStatusId = status;
    commentController.text = '';
    _pendingProofImage = null;
    if (_statusRequiresImage(status)) {
      final image = await _pickProofImage();
      if (image == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Зураг оруулна уу'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      _pendingProofImage = image;
    }
    if (mounted) _showPostponeSheet();
  }


  @override
  void initState() {
    super.initState();
    fetchDelivery();
    fetchDelivery().then((_) {
      fetchItems();
    });
  }

  Future<void> fetchDelivery() async {
    final url = Uri.parse(Url.url + '/api/delivery/${widget.deliveryId}');
    print('🔍 [DEBUG] fetchDelivery - URL: $url');
    print('🔍 [DEBUG] fetchDelivery - Delivery ID: ${widget.deliveryId}');

    try {
      final response = await http.get(url);
      print('🔍 [DEBUG] fetchDelivery - Status Code: ${response.statusCode}');
      print('🔍 [DEBUG] fetchDelivery - Raw Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('🔍 [DEBUG] fetchDelivery - Parsed JSON: $jsonResponse');
        print('🔍 [DEBUG] fetchDelivery - Success: ${jsonResponse['success']}');
        
        if (jsonResponse['success'] == true) {
          final deliveryData = jsonResponse['data'];
          print('🔍 [DEBUG] fetchDelivery - Delivery Data: $deliveryData');
          print('🔍 [DEBUG] fetchDelivery - Delivery Keys: ${deliveryData?.keys.toList()}');
          
          // Print merchant data specifically
          print('🔍 [DEBUG] fetchDelivery - Merchant: ${deliveryData?['merchant']}');
          if (deliveryData?['merchant'] != null) {
            print('🔍 [DEBUG] fetchDelivery - Merchant Type: ${deliveryData['merchant'].runtimeType}');
            print('🔍 [DEBUG] fetchDelivery - Merchant Keys: ${deliveryData['merchant'] is Map ? deliveryData['merchant'].keys.toList() : 'Not a Map'}');
            print('🔍 [DEBUG] fetchDelivery - Merchant username: ${deliveryData['merchant']?['username']}');
            print('🔍 [DEBUG] fetchDelivery - Merchant shop_phone: ${deliveryData['merchant']?['shop_phone']}');
            print('🔍 [DEBUG] fetchDelivery - Merchant phone: ${deliveryData['merchant']?['phone']}');
          } else {
            print('🔍 [DEBUG] fetchDelivery - Merchant is NULL');
          }
          
          // Print other important fields
          print('🔍 [DEBUG] fetchDelivery - Phone: ${deliveryData?['phone']}');
          print('🔍 [DEBUG] fetchDelivery - Address: ${deliveryData?['address']}');
          print('🔍 [DEBUG] fetchDelivery - Status Name: ${deliveryData?['status_name']}');
          print('🔍 [DEBUG] fetchDelivery - Price: ${deliveryData?['price']}');
          print('🔍 [DEBUG] fetchDelivery - CreatedAt: ${deliveryData?['createdAt']}');
          
          setState(() {
            delivery = deliveryData;
            isLoading = false;
            error = null;
          });
          
          print('🔍 [DEBUG] fetchDelivery - State updated successfully');
        } else {
          print('🔍 [DEBUG] fetchDelivery - Failed: ${jsonResponse['message'] ?? 'Unknown error'}');
          setState(() {
            error = 'Failed to load delivery details';
            isLoading = false;
          });
        }
      } else {
        print('🔍 [DEBUG] fetchDelivery - Server error: ${response.statusCode}');
        print('🔍 [DEBUG] fetchDelivery - Error Body: ${response.body}');
        setState(() {
          error = 'Server error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      print('🔍 [DEBUG] fetchDelivery - Exception: $e');
      print('🔍 [DEBUG] fetchDelivery - Stack Trace: ${StackTrace.current}');
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  String formatDate(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  Widget? _buildNotPickedRequestBanner() {
    final requests = delivery?['not_picked_requests'];
    if (requests is! List || requests.isEmpty) return null;
    final latest = requests.first;
    if (latest is! Map) return null;
    final status = latest['status']?.toString() ?? '';
    final adminNote = latest['admin_note']?.toString().trim() ?? '';

    if (status == 'pending') {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Text(
          'Авч гараагүй хүсэлт админд хүлээгдэж байна',
          style: _tx(fontSize: 13, color: Colors.orange.shade900, fontWeight: FontWeight.w600),
        ),
      );
    }
    if (status == 'rejected') {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Авч гараагүй хүсэлт татгалзсан',
              style: _tx(fontSize: 13, color: Colors.red.shade900, fontWeight: FontWeight.w600),
            ),
            if (adminNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Админ: $adminNote',
                style: _tx(fontSize: 12, color: Colors.red.shade800),
              ),
            ],
          ],
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Debug print when building
    print('🔍 [DEBUG] build - isLoading: $isLoading');
    print('🔍 [DEBUG] build - error: $error');
    print('🔍 [DEBUG] build - delivery: $delivery');
    if (delivery != null) {
      print('🔍 [DEBUG] build - delivery keys: ${delivery!.keys.toList()}');
      print('🔍 [DEBUG] build - delivery merchant: ${delivery!['merchant']}');
      print('🔍 [DEBUG] build - delivery merchant type: ${delivery!['merchant']?.runtimeType}');
      if (delivery!['merchant'] != null && delivery!['merchant'] is Map) {
        print('🔍 [DEBUG] build - merchant keys: ${(delivery!['merchant'] as Map).keys.toList()}');
        print('🔍 [DEBUG] build - merchant username: ${delivery!['merchant']?['username']}');
        print('🔍 [DEBUG] build - merchant shop_phone: ${delivery!['merchant']?['shop_phone']}');
      }
    }
    print('🔍 [DEBUG] build - items count: ${items.length}');
    
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Хүргэлтийн дэлгэрэнгүй',
            style: _tx(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: Color(0xFF0e0e6e),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Хүргэлтийн дэлгэрэнгүй',
            style: _tx(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: Color(0xFF0e0e6e),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(child: Text(error!)),
      );
    }

    // Static items as requested
    final notPickedBanner = _buildNotPickedRequestBanner();

    return Stack(
      children: [
        Scaffold(
      appBar: AppBar(
        title: Text(
          'Хүргэлтийн дэлгэрэнгүй',
          style: _tx(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: Color(0xFF0e0e6e),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notPickedBanner != null) notPickedBanner,
            // General Delivery Info Card
            // Inside your Column children:
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        // Debug print before building the text
                        final merchant = delivery!['merchant'];
                        final username = merchant?['username'];
                        final shopPhone = merchant?['shop_phone'];
                        print('🔍 [DEBUG] Merchant Text - merchant: $merchant');
                        print('🔍 [DEBUG] Merchant Text - username: $username (type: ${username?.runtimeType})');
                        print('🔍 [DEBUG] Merchant Text - shop_phone: $shopPhone (type: ${shopPhone?.runtimeType})');
                        
                        String merchantText;
                        try {
                          if (username != null && shopPhone != null) {
                            merchantText = "👤 Дэлгүүр: $username 📞 $shopPhone";
                          } else if (username != null) {
                            merchantText = "👤 Дэлгүүр: $username 📞 N/A";
                          } else {
                            merchantText = "👤 Дэлгүүр: N/A 📞 ${shopPhone ?? 'N/A'}";
                          }
                        } catch (e) {
                          print('🔍 [DEBUG] Merchant Text - Error building text: $e');
                          merchantText = "👤 Дэлгүүр: Error displaying merchant info";
                        }
                        
                        return Text(
                          merchantText,
                          style: _tx(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "📞 Утас: ${delivery!['phone'] ?? 'N/A'}",
                      style: _tx(
                          fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "📍 Хаяг: ${delivery!['address'] ?? 'N/A'}",
                      style: _tx(
                          fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "⏰ Цаг: ${formatDate(delivery!['createdAt'] ?? '')}",
                      style: _tx(
                          fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "🚚 Төлөв: ${delivery!['status_name']?['status'] ?? 'N/A'}",
                      style: _tx(
                        fontSize: 14,
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "💰 Үнэ: ${delivery!['price']?.toString() ?? '0'}₮",
                      style: _tx(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Тайлбар',
                      style: _tx(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (delivery!['comment']?.toString().trim().isNotEmpty == true)
                          ? delivery!['comment'].toString().trim()
                          : '—',
                      style: _tx(fontSize: 14, color: Colors.black87, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Жолоочийн тайлбар',
                      style: _tx(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (delivery!['driver_comment']?.toString().trim().isNotEmpty == true)
                          ? delivery!['driver_comment'].toString().trim()
                          : '—',
                      style: _tx(fontSize: 14, color: Colors.black87, height: 1.35),
                    ),
                  ],
                ),
              ),

            ),

            SizedBox(height: 24),
            // Static items section
            if (items.isNotEmpty) ...[
              Text(
                "📦 Бараанууд",
                style: _tx(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...items.map((item) {
                final name = item['good']?['name'] ?? 'Нэргүй бараа';
                final qty = item['quantity'] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name.toString(),
                        style: _tx(fontSize: 14),
                      ),
                      Text(
                        "Тоо: $qty",
                        style: _tx(fontSize: 14),
                      ),
                    ],
                  ),
                );
              }).toList()
            ],
            const SizedBox(height: 24),
            // Action Buttons (6)
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _actionButton("Хүргэсэн", Icons.check_circle, Colors.green,
                    () async {
                  final confirmed = await showConfirmationDialog(
                      context, 'Та итгэлтэй байна уу?');
                  if (confirmed == true) {
                    await _markAsDelivered();
                  }
                }),
                _actionButton("Цуцалсан", Icons.cancel, Colors.red, () async {
                  selectedStatusId = 5;
                  commentController.text = '';
                  _showPostponeSheet();
                }),
                _actionButton("Утсаар ярих", Icons.phone, Colors.indigo, () {
                  final phone = delivery?['phone'] ?? '';
                  if (phone.isNotEmpty) {
                    _callPhoneNumber(phone);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Утасны дугаар олдсонгүй')));
                  }
                }),
                _actionButton("Хаягаар очсон", Icons.camera_alt, Colors.orange, () {
                  _beginStatusFlow(7);
                }),
                _actionButton("Дараа авна", Icons.map, Colors.teal, () {
                  selectedStatusId = 8;
                  commentController.text = '';
                  _showPostponeSheet();
                }),
                _actionButton("Утсаа аваагүй", Icons.map, Colors.pink, () {
                  selectedStatusId = 6;
                  commentController.text = '';
                  _showPostponeSheet();
                }),
                _actionButton("Маргааш авна", Icons.schedule, Colors.blueGrey, () {
                  selectedStatusId = 9;
                  commentController.text = '';
                  _showPostponeSheet();
                }),
                _actionButton("Авч гараагүй", Icons.inventory_2, Colors.deepPurple, () {
                  commentController.text = '';
                  _showNotPickedRequestSheet();
                }),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                  final ok = await showConfirmationDialog(context, 'Итгэлтэй юу?');
                  if (ok == true && mounted) _showAddressChangeSheet();
                },
                icon: const Icon(Icons.edit_location, size: 20),
                label: Text('Хаяг солиулах', style: _tx(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5c4033),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
        if (_isSubmitting && _submittingMessage != null) _buildSubmittingOverlay(),
      ],
    );
  }

  Widget _buildSubmittingOverlay() {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black54,
          child: Center(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _submittingMessage ?? 'Илгээж байна...',
                      style: _tx(fontSize: 15, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddressChangeSheet() {
    _newAddressController.text =
        (delivery != null && delivery!['address'] != null)
            ? delivery!['address'].toString()
            : '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Шинэ хаяг оруулна уу',
                style: _tx(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'Админ зөвшөөрсний дараа сонгосон жолооч руу шилжинэ.',
                style: _tx(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newAddressController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Шинэ хаяг',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Болих'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5c4033),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await _submitAddressChangeRequest();
                        if (mounted) Navigator.pop(context);
                      },
                      child: Text(
                        'Илгээх',
                        style: _tx(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitAddressChangeRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нэвтрэх мэдээлэл олдсонгүй')),
      );
      return;
    }
    final newAddr = _newAddressController.text.trim();
    if (newAddr.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Шинэ хаягаа оруулна уу')),
      );
      return;
    }
    final url = Uri.parse(
        '${Url.url}/api/mobile/delivery/${delivery!['id']}/address-request');
    final currentAddr = delivery!['address']?.toString() ?? '';
    print(
      '[address-request] POST $url deliveryPk=${delivery!['id']} driver_user_id=$userId '
      'currentLen=${currentAddr.length} newLen=${newAddr.length} same=${newAddr == currentAddr.trim()}',
    );
    try {
      final body = jsonEncode({
        'new_address': newAddr,
        'driver_user_id': userId,
      });
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      print('[address-request] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (res.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']?.toString() ?? 'Хүсэлт илгээгдлээ'),
            backgroundColor: Colors.green,
          ),
        );
        fetchDelivery();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']?.toString() ?? 'Алдаа гарлаа'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сервертэй холбогдож чадсангүй: $e')),
      );
    }
  }

  void _showNotPickedRequestSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Авч гараагүй — админд хүсэлт',
                style: _tx(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'Зөвшөөрөгдөх хүртэл хүргэлт төлөв 2 хэвээр үлдэнэ. Админ зөвшөөрснөөр төлөв 10 болно.',
                style: _tx(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Тайлбар (заавал биш)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Болих'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await _submitNotPickedRequest();
                        if (mounted) Navigator.pop(context);
                      },
                      child: Text(
                        'Илгээх',
                        style: _tx(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitNotPickedRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нэвтрэх мэдээлэл олдсонгүй')),
      );
      return;
    }
    final url = Uri.parse(
        '${Url.url}/api/mobile/delivery/${delivery!['id']}/not-picked-request');
    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driver_user_id': userId,
          'driver_comment': commentController.text.trim(),
        }),
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (res.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']?.toString() ?? 'Хүсэлт илгээгдлээ'),
            backgroundColor: Colors.green,
          ),
        );
        fetchDelivery();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']?.toString() ?? 'Алдаа гарлаа'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сервертэй холбогдож чадсангүй: $e')),
      );
    }
  }

  Widget _buildProofImagePreview(File imageFile) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.file(
        imageFile,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey.shade500,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, color: Colors.grey.shade500),
              const SizedBox(height: 6),
              Text(
                'Зураг ачаалж чадсангүй',
                style: _tx(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPostponeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !_isSubmitting,
      enableDrag: !_isSubmitting,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        var sheetSubmitting = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> handleSubmit() async {
              if (sheetSubmitting) return;
              setSheetState(() => sheetSubmitting = true);
              var success = false;
              try {
                success = await _submitPostpone(
                  showOverlay: false,
                  navigateOnSuccess: false,
                );
                if (!sheetContext.mounted) return;
                if (success) {
                  Navigator.pop(sheetContext);
                  if (!mounted) return;
                  final prefs = await SharedPreferences.getInstance();
                  final userId = prefs.getInt('user_id');
                  if (userId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MainScreen(id: userId),
                      ),
                    );
                  }
                }
              } finally {
                if (!success && sheetContext.mounted) {
                  setSheetState(() => sheetSubmitting = false);
                }
              }
            }

            final uploadMessage = _pendingProofImage != null
                ? 'Зураг илгээж байна...'
                : 'Хадгалагдаж байна...';

            return PopScope(
              canPop: !sheetSubmitting,
              child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('Тайлбар нэмэх',
                      style: _tx(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  if (_pendingProofImage != null) ...[
                    _buildProofImagePreview(_pendingProofImage!),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: commentController,
                    enabled: !sheetSubmitting,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Тайлбар',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (sheetSubmitting) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.deepOrange.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              uploadMessage,
                              style: _tx(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.deepOrange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: sheetSubmitting
                              ? null
                              : () => Navigator.pop(sheetContext),
                          child: const Text('Болих'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            disabledBackgroundColor:
                                Colors.deepOrange.withValues(alpha: 0.6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: sheetSubmitting ? null : handleSubmit,
                          child: sheetSubmitting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Илгээж байна...',
                                      style: _tx(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              : Text('Хадгалах',
                                  style: _tx(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
    );
  }


  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _isSubmitting ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        textStyle: _tx(fontSize: 11),
      ),
    );
  }

  Future<bool?> showConfirmationDialog(BuildContext context, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
              SizedBox(width: 8),
              Text(
                'Анхааруулга',
                style: _tx(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: _tx(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.close, color: Colors.red),
              label: Text(
                'Үгүй',
                style: _tx(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton.icon(
              icon: Icon(Icons.check_circle, color: Colors.green),
              label: Text(
                'Тийм',
                style: _tx(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markAsDelivered() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    File? imageFile;
    if (_isRural) {
      imageFile = await _pickProofImage();
      if (imageFile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Орон нутгийн хүргэлтэд зураг заавал оруулна'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _submittingMessage = imageFile != null
          ? 'Зураг илгээж байна...'
          : 'Хадгалагдаж байна...';
    });

    try {
      final ok = await _submitComplete(3, imageFile: imageFile);
      if (!ok || !mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Хүргэлт амжилттай хүргэгдлээ'),
          backgroundColor: Colors.green,
        ),
      );

      if (userId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MainScreen(id: userId)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingMessage = null;
        });
      }
    }
  }

  Future<void> _markasDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id'); // ✅ Retrieve from shared
    print('🔍 [DEBUG] _markasDeclined - User ID: $userId');

    final url =
        Uri.parse(Url.url + '/api/mobile/delivery/complete/${delivery!['id']}');
    print('🔍 [DEBUG] _markasDeclined - URL: $url');
    print('🔍 [DEBUG] _markasDeclined - Delivery ID: ${delivery!['id']}');

    final requestBody = {'status': 5};
    print('🔍 [DEBUG] _markasDeclined - Request Body: ${jsonEncode(requestBody)}');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );
    
    print('🔍 [DEBUG] _markasDeclined - Response Status: ${response.statusCode}');
    print('🔍 [DEBUG] _markasDeclined - Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('🔍 [DEBUG] _markasDeclined - Response Data: $data');
      print('🔍 [DEBUG] _markasDeclined - Success: ${data['success']}');
      
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хүргэлт цуцлагдлаа'),
            backgroundColor: Colors.red,
          ),
        );

        // ✅ Navigate to MainScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(id: userId!),
          ),
        );
      } else {
        print('🔍 [DEBUG] _markasDeclined - Failed: ${data['message'] ?? 'Unknown error'}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? 'Алдаа гарлаа'),
              backgroundColor: Colors.red),
        );
      }
    } else {
      print('🔍 [DEBUG] _markasDeclined - Server error: ${response.statusCode}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Сервертэй холбогдож чадсангүй'),
            backgroundColor: Colors.red),
      );
    }
  }
}
