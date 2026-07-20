import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../app_text.dart';

import '../color/color.dart';

class UserDetailScreen extends StatefulWidget {
  @override
  _UserDetailScreenState createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactInfoController = TextEditingController(); // ✅ Added

  bool _isLoading = false;
  bool _isEditing = false;
  Map<String, dynamic>? _userData;
  String? _selectedBank;

  // List of available banks
  final List<String> _banks = [
    'Khaan Bank',
    'TDB Bank',
    'Golomt Bank',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Fetch user data from backend using user_id from SharedPreferences
  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');

      if (userId == null) {
        throw Exception('User ID not found in SharedPreferences');
      }

      print('Fetching user data for ID: $userId');

      final response = await http.get(
        Uri.parse('${Url.url}/api/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle both string "true" and boolean true
        bool isSuccess = responseData['success'] == true ||
            responseData['success'] == 'true';

        if (isSuccess) {
          // Format 1: {success: true, data: {...}}
          setState(() {
            _userData = responseData['data'];
            // Fill form with existing data - handle missing fields
            _selectedBank = _userData?['bank'] ?? '';
            _accountNumberController.text = _userData?['account_number'] ?? '';
            _phoneController.text = _userData?['phone'] ?? '';
            _addressController.text = _userData?['address'] ?? '';
            _contactInfoController.text = _userData?['contact_info'] ?? ''; // ✅ Added
          });
        } else if (responseData['id'] != null) {
          // Format 2: Direct user object {id: 3, username: ...}
          setState(() {
            _userData = responseData;
            // Fill form with existing data - handle missing fields
            _selectedBank = _userData?['bank'] ?? '';
            _accountNumberController.text = _userData?['account_number'] ?? '';
            _phoneController.text = _userData?['phone'] ?? '';
            _addressController.text = _userData?['address'] ?? '';
            _contactInfoController.text = _userData?['contact_info'] ?? ''; // ✅ Added
          });
        } else {
          throw Exception('Invalid response format: ${responseData}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching user data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Update user data
  Future<void> _updateUserData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Prepare update data - only include fields that have values
      final Map<String, dynamic> updateData = {};

      if (_selectedBank != null && _selectedBank!.isNotEmpty) {
        updateData['bank'] = _selectedBank;
      }
      if (_accountNumberController.text.isNotEmpty) {
        updateData['account_number'] = _accountNumberController.text.trim();
      }
      if (_phoneController.text.isNotEmpty) {
        updateData['phone'] = _phoneController.text.trim();
      }
      if (_addressController.text.isNotEmpty) {
        updateData['address'] = _addressController.text.trim();
      }
      if (_contactInfoController.text.isNotEmpty) { // ✅ Added
        updateData['contact_info'] = _contactInfoController.text.trim();
      }

      // If no data to update, show message and return
      if (updateData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Шинэчлэх мэдээлэл оруулна уу!')),
        );
        return;
      }

      final response = await http.put(
        Uri.parse('${Url.url}/api/user/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updateData),
      );
      print('${Url.url}/api/user/$userId');
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Амжилттай шинэчлэгдлээ!')),
          );
          setState(() {
            _isEditing = false;
            _userData = responseData['data'];
          });
        } else {
          throw Exception('Failed to update: ${responseData['message']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating user data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Хэрэглэгчийн мэдээлэл',
          style: appText(color: Colors.white),
        ),
        backgroundColor: Color(0xFF0e0e6e),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  // Reset form to original values
                  _selectedBank = _userData?['bank'] ?? '';
                  _accountNumberController.text = _userData?['account_number'] ?? '';
                  _phoneController.text = _userData?['phone'] ?? '';
                  _addressController.text = _userData?['address'] ?? '';
                  _contactInfoController.text = _userData?['contact_info'] ?? ''; // ✅ Added
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _userData == null
          ? Center(
        child: Text(
          'Хэрэглэгчийн мэдээлэл олдсонгүй',
          style: appText(fontSize: 16),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // User Info Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Хэрэглэгчийн мэдээлэл',
                        style: appText(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildInfoRow('Нэр:', _userData!['username'] ?? '-'),
                      _buildInfoRow('Имэйл:', _userData!['email'] ?? '-'),
                      _buildInfoRow('Үүрэг:', _getRoleText(_userData!['role_id'] ?? 0)),
                      _buildInfoRow('Бүртгүүлсэн:', _formatDate(_userData!['createdAt'])),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Editable Fields Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Хувийн мэдээлэл',
                        style: appText(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Bank Selection
                      Text(
                        'Банк',
                        style: appText(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      _isEditing
                          ? DropdownButtonFormField<String>(
                        value: _selectedBank?.isEmpty ?? true ? null : _selectedBank,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          hintText: 'Банкаа сонгоно уу',
                        ),
                        items: _banks.map((String bank) {
                          return DropdownMenuItem<String>(
                            value: bank,
                            child: Text(bank, style: appText()),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedBank = newValue;
                          });
                        },
                      )
                          : _buildInfoRow('Банк:', _selectedBank?.isEmpty ?? true ? 'Оруулаагүй' : _selectedBank!),
                      SizedBox(height: 16),

                      // Account Number
                      Text(
                        'Дансны дугаар',
                        style: appText(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      _isEditing
                          ? TextFormField(
                        controller: _accountNumberController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Дансны дугаараа оруулна уу',
                        ),
                      )
                          : _buildInfoRow('Дансны дугаар:', _accountNumberController.text.isNotEmpty ? _accountNumberController.text : 'Оруулаагүй'),
                      SizedBox(height: 16),

                      // Phone Number
                      Text(
                        'Утасны дугаар',
                        style: appText(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      _isEditing
                          ? TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Утасны дугаараа оруулна уу',
                          prefixText: _userData?['phone'] != null ? '' : null,
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Утасны дугаар оруулна уу';
                          }
                          return null;
                        },
                      )
                          : _buildInfoRow('Утасны дугаар:', _userData?['phone'] ?? (_phoneController.text.isNotEmpty ? _phoneController.text : 'Оруулаагүй')),
                      SizedBox(height: 16),

                      // ✅ Added: Contact Info
                      Text(
                        'Холбоо барих хүнийн дугаар',
                        style: appText(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      _isEditing
                          ? TextFormField(
                        controller: _contactInfoController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Холбоо барих хүнийн дугаараа оруулна уу',
                        ),
                        keyboardType: TextInputType.phone,
                      )
                          : _buildInfoRow('Холбоо барих дугаар:', _contactInfoController.text.isNotEmpty ? _contactInfoController.text : 'Оруулаагүй'),
                      SizedBox(height: 16),

                      // Address
                      Text(
                        'Хаяг',
                        style: appText(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      _isEditing
                          ? TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Хаягаа оруулна уу',
                        ),
                        maxLines: 3,
                      )
                          : _buildInfoRow('Хаяг:', _addressController.text.isNotEmpty ? _addressController.text : 'Оруулаагүй'),
                      SizedBox(height: 20),

                      // Save Button
                      if (_isEditing)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _updateUserData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0e0e6e),
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: _isLoading
                                ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : Text(
                              'Хадгалах',
                              style: appText(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: appText(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: appText(),
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleText(int role) {
    switch (role) {
      case 1:
        return 'Админ';
      case 2:
        return 'Хэрэглэгч';
      case 3:
        return 'Жолооч';
      default:
        return 'Тодорхойгүй';
    }
  }

  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _contactInfoController.dispose(); // ✅ Added
    super.dispose();
  }
}