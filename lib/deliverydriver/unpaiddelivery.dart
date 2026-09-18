import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_text.dart';
import '../screen/login.dart';
import 'dashboard.dart';
import 'delivery_done_shared.dart';
import 'detaildelivery.dart';

class UnpaidDone extends StatefulWidget {
  const UnpaidDone({Key? key}) : super(key: key);

  @override
  State<UnpaidDone> createState() => _UnpaidDoneState();
}

class _UnpaidDoneState extends State<UnpaidDone> {
  static const int _pageSize = 50;

  List<DoneDelivery> deliveries = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  int currentPage = 1;
  int totalCount = 0;
  DateTime? _startDate;
  DateTime? _endDate;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    fetchDeliveries();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!hasMore || isLoading || isLoadingMore) return;
    if (!_scrollController.hasClients) return;

    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      loadMoreDeliveries();
    }
  }

  Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  Future<void> fetchDeliveries({DateTime? startDate, DateTime? endDate}) async {
    setState(() {
      isLoading = true;
      currentPage = 1;
      hasMore = true;
    });

    final userId = await _getUserId();
    if (userId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final result = await fetchDoneDeliveriesPage(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
        unpaidOnly: true,
        page: 1,
        limit: _pageSize,
      );
      setState(() {
        deliveries = result.items;
        totalCount = result.total;
        hasMore = result.hasMore;
        currentPage = result.page;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load unpaid deliveries: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> loadMoreDeliveries() async {
    if (!hasMore || isLoading || isLoadingMore) return;

    setState(() => isLoadingMore = true);

    final userId = await _getUserId();
    if (userId == null) {
      setState(() => isLoadingMore = false);
      return;
    }

    try {
      final nextPage = currentPage + 1;
      final result = await fetchDoneDeliveriesPage(
        userId: userId,
        startDate: _startDate,
        endDate: _endDate,
        unpaidOnly: true,
        page: nextPage,
        limit: _pageSize,
      );

      setState(() {
        deliveries = [...deliveries, ...result.items];
        totalCount = result.total;
        hasMore = result.hasMore;
        currentPage = result.page;
        isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('Failed to load more unpaid deliveries: $e');
      setState(() => isLoadingMore = false);
    }
  }

  Future<void> _markAsPaid(DoneDelivery delivery) async {
    if (delivery.statusCode != 3) return;

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
      deliveries.removeWhere((d) => d.id == delivery.id);
      if (totalCount > 0) totalCount -= 1;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await fetchDeliveries(startDate: _startDate, endDate: _endDate);
    }
  }

  Future<void> _clearDateFilter() async {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    await fetchDeliveries();
  }

  String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd – kk:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.dashboard, color: Colors.white),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => Dashboard()));
          },
        ),
        title: Text('Тооцоо аваагүй', style: appText(color: Colors.white, fontSize: 13)),
        backgroundColor: const Color(0xFF0e0e6e),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt, color: Colors.white),
            onPressed: _pickDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _clearDateFilter,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    totalCount > 0
                        ? 'Тооцоо аваагүй: ${deliveries.length} / $totalCount'
                        : 'Тооцоо аваагүй: ${deliveries.length}',
                    style: appText(fontSize: 16, fontWeight: FontWeight.bold),
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
                            style: appText(fontSize: 12, color: Colors.white),
                          ),
                          backgroundColor: Colors.blueGrey,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _clearDateFilter,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: deliveries.isEmpty
                      ? Center(
                          child: Text(
                            'Тооцоо аваагүй хүргэлт байхгүй',
                            style: appText(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: deliveries.length + (isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= deliveries.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final delivery = deliveries[index];
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
                              onDoubleTap: () => _markAsPaid(delivery),
                              child: Card(
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: doneStatusColor(delivery.status),
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
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Тооцоо аваагүй',
                                              style: appText(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Үүсэн: ${formatDate(delivery.createdDate)}',
                                        style: appText(color: Colors.grey[700], fontSize: 11),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Утас: ${delivery.phone}',
                                        style: appText(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              delivery.comment,
                                              style: appText(
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '₮ ${delivery.price}',
                                              textAlign: TextAlign.right,
                                              style: appText(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        delivery.address,
                                        style: appText(fontSize: 11, color: Colors.grey[800]),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Давхар дарж тооцоо авсан гэж тэмдэглэнэ',
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
