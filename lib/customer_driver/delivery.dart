import 'dart:convert';
import '../app_text.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/customer_driver/cust_dashboard.dart';
import 'package:sura_driver/deliverydriver/detaildelivery.dart';
import 'package:http/http.dart' as http;

import '../color/color.dart';
import '../deliverydriver/createDelivery.dart';
import '../screen/login.dart';
import '../deliverydriver/createDelivery.dart';

class Delivery {
  final int id;
  final String phone;
  String status;
  final DateTime createdDate;
  String comment;
  final String address;
  final String? driverComment;
  final String? color; // Make color nullable since it might not come from API
  final DateTime updatedAt;
  List<String> possibleStatuses;

  Delivery({
    required this.id,
    required this.phone,
    required this.status,
    required this.createdDate,
    required this.comment,
    required this.address,
    this.driverComment,
    this.color, // Make color optional
    required this.updatedAt,
    this.possibleStatuses = const [
      "шинэ",
      "жолоочид",
      "хүргэгдсэн",
      "буцаасан",
      "хаягаар очсон",
      "дараа авна",
      "маргааш авна",
      "утсаа аваагүй"
    ],
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    // Handle phone field - convert to string if it's int
    String phone = '';
    if (json['phone'] != null) {
      phone = json['phone'].toString();
    }

    // Handle status field - if it's int, map to Mongolian text; if string, use as is
    String status = 'шинэ';
    if (json['status'] != null) {
      if (json['status'] is int) {
        // Map integer status to Mongolian text based on your actual backend IDs
        status = _statusFromCode(json['status']);
      } else {
        status = json['status'].toString();
      }
    }

    // Handle comment field - convert to string if it's int or null
    String comment = '';
    if (json['comment'] != null) {
      comment = json['comment'].toString();
    }

    // Handle address field - convert to string if it's int or null
    String address = '';
    if (json['address'] != null) {
      address = json['address'].toString();
    }

    // Handle driver_comment field
    String? driverComment;
    if (json['driver_comment'] != null) {
      driverComment = json['driver_comment'].toString();
    } else if (json['driverComment'] != null) {
      driverComment = json['driverComment'].toString();
    }

    // Handle color field - might not be present in delivery data
    String? color;
    if (json['color'] != null) {
      color = json['color'].toString();
    }

    return Delivery(
      id: json['id'] ?? 0,
      phone: phone,
      status: status,
      createdDate: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      comment: comment,
      address: address,
      driverComment: driverComment,
      color: color, // Can be null
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Map integer status codes to Mongolian status names based on your actual backend
  static String _statusFromCode(int statusCode) {
    switch (statusCode) {
      case 1:
        return "шинэ";
      case 2:
        return "жолоочид";
      case 3:
        return "хүргэгдсэн";
      case 5:
        return "буцаасан";
      case 6:
        return "утсаа аваагүй";
      case 7:
        return "хаягаар очсон";
      case 8:
        return "дараа авна";
      case 9:
        return "маргааш авна";
      default:
        return "шинэ";
    }
  }

  // Convert Mongolian status back to integer code for API calls
  static int _codeFromStatus(String status) {
    switch (status) {
      case "шинэ":
        return 1;
      case "жолоочид":
        return 2;
      case "хүргэгдсэн":
        return 3;
      case "буцаасан":
        return 5;
      case "утсаа аваагүй":
        return 6;
      case "хаягаар очсон":
        return 7;
      case "дараа авна":
        return 8;
      case "маргааш авна":
        return 9;
      default:
        return 1;
    }
  }

  // Get status code for API calls
  int get statusCode => _codeFromStatus(status);
}

class DeliveryCustomer extends StatefulWidget {
  @override
  _DeliveryCustomerState createState() => _DeliveryCustomerState();
}

class _DeliveryCustomerState extends State<DeliveryCustomer> {
  List<Delivery> deliveries = [];
  List<Delivery> allDeliveries = []; // Store all deliveries for filtering
  int? expandedIndex;
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();
  Set<String> selectedStatuses = {}; // Selected statuses for filtering

  // Statuses from your backend (in Mongolian)
  List<String> statuses = [
    "шинэ",
    "жолоочид",
    "хүргэгдсэн",
    "буцаасан",
    "хаягаар очсон",
    "дараа авна",
    "маргааш авна",
    "утсаа аваагүй"
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchDeliveries() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('user_id');
    final url =
    Uri.parse(Url.url + '/api/mobile/delivery/merchant?user_id=$userId');
    print(url);
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List data = jsonResponse['data'];

        setState(() {
          allDeliveries = data.map((item) => Delivery.fromJson(item)).toList();
          deliveries = allDeliveries;
          isLoading = false;
        });
        _applyFilters();
        print('Fetched ${deliveries.length} deliveries');
        // Debug: print first delivery to see the status mapping
        if (deliveries.isNotEmpty) {
          print('First delivery status: ${deliveries[0].status}');
          print('First delivery color: ${deliveries[0].color}');
        }
      } else {
        print('Error: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Failed to load deliveries: $e');
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
          expandedIndex = null;
          // Update in allDeliveries as well
          final allIndex = allDeliveries.indexWhere((d) => d.id == delivery.id);
          if (allIndex != -1) {
            allDeliveries[allIndex].status = newStatus;
          }
        });
        _applyFilters();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Статус амжилттай шинэчлэгдлээ'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('Failed to update status: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Статус шинэчлэхэд алдаа гарлаа'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error updating status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Алдаа гарлаа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> deleteDelivery(int index) async {
    final delivery = deliveries[index];
    
    // Check if status is "шинэ" (new) or status code is 1
    if (delivery.status != "шинэ" && delivery.statusCode != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Зөвхөн шинэ хүргэлтийг устгах боломжтой'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Хүргэлт устгах'),
        content: Text('Та энэ хүргэлтийг устгахдаа итгэлтэй байна уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Үгүй'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Тийм', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final url = Uri.parse(Url.url + '/api/delivery/${delivery.id}');
    
    try {
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() {
          final deliveryId = deliveries[index].id;
          deliveries.removeAt(index);
          allDeliveries.removeWhere((d) => d.id == deliveryId);
          expandedIndex = null;
        });
        _applyFilters();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хүргэлт амжилттай устгагдлаа'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('Failed to delete delivery: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хүргэлт устгахад алдаа гарлаа'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error deleting delivery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Алдаа гарлаа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "шинэ":
        return Colors.amber[700]!; // Darker amber
      case "жолоочид":
        return Colors.blue;
      case "хүргэгдсэн":
        return Colors.green;
      case "буцаасан":
        return Colors.red;
      case "хаягаар очсон":
        return Colors.indigo;
      case "дараа авна":
        return Colors.brown;
      case "маргааш авна":
        return Colors.cyan;
      case "утсаа аваагүй":
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd – kk:mm').format(date);
  }

  void _applyFilters() {
    setState(() {
      deliveries = allDeliveries.where((delivery) {
        // Filter by phone search
        final phoneMatch = searchController.text.isEmpty ||
            delivery.phone.toLowerCase().contains(searchController.text.toLowerCase());
        
        // Filter by status
        final statusMatch = selectedStatuses.isEmpty ||
            selectedStatuses.contains(delivery.status);
        
        return phoneMatch && statusMatch;
      }).toList();
    });
  }

  void _showStatusFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Төлөв шүүх',
                        style: appText(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: statuses.map((status) {
                          final isSelected = selectedStatuses.contains(status);
                          return CheckboxListTile(
                            title: Text(
                              status,
                              style: appText(),
                            ),
                            value: isSelected,
                            activeColor: getStatusColor(status),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  selectedStatuses.add(status);
                                } else {
                                  selectedStatuses.remove(status);
                                }
                              });
                            },
                            secondary: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: getStatusColor(status),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              selectedStatuses.clear();
                            });
                          },
                          child: Text(
                            'Цэвэрлэх',
                            style: appText(),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _applyFilters();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0e0e6e),
                          ),
                          child: Text(
                            'Хэрэглэх',
                            style: appText(color: Colors.white),
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
      },
    );
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
          icon: Icon(Icons.dashboard, color: Colors.white),
          tooltip: 'Dashboard',
          onPressed: () {
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => CustDashboard()));
          },
        ),
        title: Text(
          'Хүргэлт',
          style: appText(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: Color(0xFF0e0e6e),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.filter_list, color: Colors.white),
                if (selectedStatuses.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        '${selectedStatuses.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Төлөв шүүх',
            onPressed: _showStatusFilterModal,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              fetchDeliveries();
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
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
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Container(
                  padding: EdgeInsets.all(12),
                  color: Colors.white,
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Утасны дугаараар хайх...',
                      hintStyle: appText(),
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    style: appText(),
                    onChanged: (value) {
                      _applyFilters();
                    },
                  ),
                ),
                // Filter chips (if any statuses are selected)
                if (selectedStatuses.isNotEmpty)
                  Container(
                    height: 50,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: selectedStatuses.map((status) {
                        return Container(
                          margin: EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(
                              status,
                              style: appText(fontSize: 11),
                            ),
                            backgroundColor: getStatusColor(status),
                            labelStyle: TextStyle(color: Colors.white),
                            deleteIcon: Icon(Icons.close, size: 16, color: Colors.white),
                            onDeleted: () {
                              setState(() {
                                selectedStatuses.remove(status);
                              });
                              _applyFilters();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                // Deliveries list
                Expanded(
                  child: deliveries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                              SizedBox(height: 16),
                              Text(
                                'Хүргэлт олдсонгүй',
                                style: appText(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: deliveries.length,
                          itemBuilder: (context, index) {
          final delivery = deliveries[index];
          final isExpanded = expandedIndex == index;

          return InkWell(
            onTap: () {
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => DeliveryDetailScreen(delivery: delivery),
              //   ),
              // );
            },
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status and Phone row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Status badge - FIXED: Use getStatusColor method
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
                              color: getStatusColor(delivery.status), // Use the method here
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
                        ),
                        Text(
                          delivery.phone,
                          style: appText(
                              color: Colors.grey[700], fontSize: 12),
                        ),
                      ],
                    ),

                    // Status selection chips (only when expanded)
                    if (isExpanded) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Статус солих:',
                        style: appText(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: statuses.map((status) {
                          final selected = status == delivery.status;
                          return ChoiceChip(
                            label: Text(
                              status,
                              style: appText(
                                fontSize: 11,
                                color: selected
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            selected: selected,
                            selectedColor: getStatusColor(status), // Use the method here too
                            onSelected: (selected) {
                              if (selected) {
                                updateStatus(index, status);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Driver Comment Tag - Only show if driver comment exists
                    if (delivery.driverComment != null &&
                        delivery.driverComment!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.purple.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.drive_eta,
                              color: Colors.purple,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Жолоочийн тайлбар: ${delivery.driverComment!}",
                                style: appText(
                                  fontSize: 11,
                                  color: Colors.purple[800],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    Text(
                      'Үүссэн: ${formatDate(delivery.createdDate)}',
                      style: appText(
                          color: Colors.grey[700], fontSize: 11),
                    ),

                    const SizedBox(height: 6),

                    // Comment
                    if (delivery.comment.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Тайлбар:',
                            style: appText(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            delivery.comment,
                            style: appText(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 10),

                    // Address
                    Text(
                      'Хаяг: ${delivery.address}',
                      style: appText(
                        fontSize: 11,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // Delete button - only show for new deliveries (status "шинэ" or status code 1)
                    if (delivery.status == "шинэ" || delivery.statusCode == 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => deleteDelivery(index),
                            tooltip: 'Устгах',
                            iconSize: 20,
                          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateDelivery()),
          ).then((_) {
            // Refresh the list when returning from CreateDelivery
            fetchDeliveries();
          });
        },
        backgroundColor: Color(0xFF0e0e6e),
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'Шинэ хүргэлт нэмэх',
      ),
    );
  }
}