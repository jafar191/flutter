import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../screens/merchant/order_details_screen.dart';
import '../admin/admin_user_profile_screen.dart'; // This import seems unused in this file.
import '../../common/custom_snackbar.dart'; // Assuming this file exists and contains showCustomSnackBar.


class AdminOrderManagementScreen extends StatefulWidget {
  final String? initialFilterStatus;
  final String? userId;
  final String? userType;

  const AdminOrderManagementScreen({
    super.key,
    this.initialFilterStatus,
    this.userId,
    this.userType,
  });

  @override
  State<AdminOrderManagementScreen> createState() => _AdminOrderManagementScreenState();
}

class _AdminOrderManagementScreenState extends State<AdminOrderManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedStatus = 'all';
  String? _selectedMerchantId;
  String? _selectedDriverId;

  Map<String, String> _merchantNames = {};
  Map<String, String> _driverNames = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialFilterStatus != null) {
      _selectedStatus = widget.initialFilterStatus!;
    }
    if (widget.userId != null) {
      if (widget.userType == 'merchant') {
        _selectedMerchantId = widget.userId;
      } else if (widget.userType == 'driver') {
        _selectedDriverId = widget.userId;
      }
    }
    _fetchUserNames();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserNames() async {
    try {
      QuerySnapshot usersSnapshot = await _firestore.collection('users').get();
      Map<String, String> merchants = {};
      Map<String, String> drivers = {};

      for (var doc in usersSnapshot.docs) {
        if (doc['userType'] == 'merchant') {
          merchants[doc.id] = doc['name'] ?? doc['storeName'] ?? 'تاجر غير معروف';
        } else if (doc['userType'] == 'driver') {
          drivers[doc.id] = doc['name'] ?? 'مندوب غير معروف';
        }
      }
      if (mounted) {
        setState(() {
          _merchantNames = merchants;
          _driverNames = drivers;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching user names for filters: ${e.message}");
      if (mounted) {
        showCustomSnackBar(context, 'حدث خطأ في Firebase عند جلب أسماء المستخدمين: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error fetching user names for filters: $e"); // Removed unnecessary braces
      if (mounted) {
        showCustomSnackBar(context, 'تعذر جلب أسماء التجار والمندوبين.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    Query query = _firestore.collection('orders');

    if (_selectedStatus != 'all') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }
    if (_selectedMerchantId != null) {
      query = query.where('merchantId', isEqualTo: _selectedMerchantId);
    }
    if (_selectedDriverId != null) {
      query = query.where('driverId', isEqualTo: _selectedDriverId);
    }

    query = query.orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text("إدارة الطلبات", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'ابحث برقم الطلب أو رقم الزبون',
                hintText: 'أدخل رقم الطلب أو رقم هاتف الزبون',
                prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  color: Colors.grey,
                )
                    : null,
                filled: Theme.of(context).inputDecorationTheme.filled,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                border: Theme.of(context).inputDecorationTheme.border,
                enabledBorder: Theme.of(context).inputDecorationTheme.enabledBorder,
                focusedBorder: Theme.of(context).inputDecorationTheme.focusedBorder,
                labelStyle: Theme.of(context).inputDecorationTheme.labelStyle,
                hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                contentPadding: Theme.of(context).inputDecorationTheme.contentPadding,
              ),
              onChanged: (value) {
                setState(() {});
              },
              style: textTheme.bodyMedium,
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildStatusFilterChip('الكل', 'all'),
                _buildStatusFilterChip('مسجلة', 'pending'),
                _buildStatusFilterChip('قيد التوصيل', 'in_progress'),
                _buildStatusFilterChip('مكتملة', 'delivered'),
                _buildStatusFilterChip('مشاكل', 'reported'),
                _buildStatusFilterChip('مرتجعة', 'return_requested'),
                _buildStatusFilterChip('تم الإرجاع', 'return_completed'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color.fromRGBO(189, 189, 189, 1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        hint: Text('التاجر', style: textTheme.bodyMedium),
                        value: _selectedMerchantId,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedMerchantId = newValue;
                          });
                        },
                        items: [
                          const DropdownMenuItem(value: null, child: Text('كل التجار', style: TextStyle(fontFamily: 'Cairo'))),
                          ..._merchantNames.keys.map((id) => DropdownMenuItem(
                            value: id,
                            child: Text(_merchantNames[id]!, style: textTheme.bodyMedium, overflow: TextOverflow.ellipsis,),
                          )),
                        ],
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                        icon: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                        isExpanded: true,
                        menuMaxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color.fromRGBO(189, 189, 189, 1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        hint: Text('المندوب', style: textTheme.bodyMedium),
                        value: _selectedDriverId,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedDriverId = newValue;
                          });
                        },
                        items: [
                          const DropdownMenuItem(value: null, child: Text('كل المندوبين', style: TextStyle(fontFamily: 'Cairo'))),
                          ..._driverNames.keys.map((id) => DropdownMenuItem(
                            value: id,
                            child: Text(_driverNames[id]!, style: textTheme.bodyMedium, overflow: TextOverflow.ellipsis,),
                          )),
                        ],
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                        icon: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                        isExpanded: true,
                        menuMaxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                }
                if (snapshot.hasError) {
                  debugPrint("Order Stream Error: ${snapshot.error}");
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'حدث خطأ في جلب الطلبات: ${snapshot.error}',
                        style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
                        textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
                        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
                      ),
                    ),
                  );
                }
                if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_outlined, size: 80, color: Color.fromRGBO(189, 189, 189, 1)),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد طلبات مطابقة للمعايير حالياً.',
                          style: textTheme.titleMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                          textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
                          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
                        ),
                      ],
                    ),
                  );
                }

                final String searchText = _searchController.text.toLowerCase();
                final List<DocumentSnapshot> filteredOrders = snapshot.data!.docs.where((orderDoc) {
                  if (searchText.isEmpty) return true;

                  final String orderNumber = (orderDoc['orderNumber']?.toString() ?? orderDoc.id).toLowerCase();
                  final String customerPhone = (orderDoc['customerPhone'] ?? '').toLowerCase();

                  return orderNumber.contains(searchText) || customerPhone.contains(searchText);
                }).toList();

                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 80, color: Color.fromRGBO(189, 189, 189, 1)),
                        const SizedBox(height: 16),
                        Text(
                          'لم يتم العثور على الطلب. تأكد من المعلومات المدخلة.',
                          style: textTheme.titleMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                          textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
                          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12.0),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot orderDoc = filteredOrders[index];
                    String merchantName = _merchantNames[orderDoc['merchantId']] ?? 'تاجر غير معروف';
                    String driverName = _driverNames[orderDoc['driverId']] ?? 'لم يُعين';

                    Color statusColor = _getStatusColor(orderDoc['status'] as String? ?? 'unknown', colorScheme);

                    return Card(
                      elevation: cardTheme.elevation,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: cardTheme.shape,
                      color: cardTheme.color,
                      child: InkWell(
                        // Fixed: The argument type 'BorderRadiusGeometry' can't be assigned to the parameter type 'BorderRadius?'.
                        borderRadius: cardTheme.shape is RoundedRectangleBorder
                            ? (cardTheme.shape as RoundedRectangleBorder).borderRadius
                            : BorderRadius.circular(12.0),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailsScreen(orderId: orderDoc.id),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // Use isRtl
                            children: [
                              Text(
                                'طلب رقم: #${orderDoc['orderNumber'] ?? orderDoc.id}',
                                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                                textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
                                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
                              ),
                              const SizedBox(height: 8.0),
                              Text(
                                'التاجر: $merchantName',
                                style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                                textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
                                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
                              ),
                              Text(
                                'المندوب: $driverName',
                                style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                                textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
                                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                'العميل: ${orderDoc['customerName'] ?? ''} | الهاتف: ${orderDoc['customerPhone'] ?? ''}',
                                style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                                textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
                                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
                              ),
                              const SizedBox(height: 8.0),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${orderDoc['totalPrice']?.toStringAsFixed(0) ?? '0'} د.ع',
                                    style: textTheme.titleLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                                    textDirection: TextDirection.ltr, // Keep LTR for numbers
                                  ),
                                  Text(
                                    'الحالة: ${_translateStatus(orderDoc['status'] as String? ?? 'unknown')}',
                                    style: textTheme.bodyLarge?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                                    textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
                                    textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              Align(
                                alignment: isRtl ? Alignment.bottomRight : Alignment.bottomLeft, // Use isRtl
                                child: Text(
                                  'التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format((orderDoc['createdAt'] as Timestamp).toDate())}',
                                  style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                                  textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
                                  textDirection: TextDirection.ltr, // Keep LTR for dates
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String label, String statusValue) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Text(label, style: textTheme.labelLarge?.copyWith(
          color: _selectedStatus == statusValue ? colorScheme.onPrimary : colorScheme.onSurface,
        )),
        selected: _selectedStatus == statusValue,
        onSelected: (bool selected) {
          setState(() {
            _selectedStatus = selected ? statusValue : 'all';
          });
        },
        selectedColor: colorScheme.primary,
        checkmarkColor: colorScheme.onPrimary,
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        side: BorderSide(
          color: _selectedStatus == statusValue ? colorScheme.primary : const Color.fromRGBO(189, 189, 189, 1),
        ),
      ),
    );
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'pending': return 'مسجلة';
      case 'in_progress': return 'قيد التوصيل';
      case 'delivered': return 'تم التوصيل';
      case 'reported': return 'مشكلة مبلغ عنها';
      case 'return_requested': return 'مرتجعة';
      case 'return_completed': return 'تم الإرجاع';
      case 'cancelled': return 'ملغاة';
      default: return status;
    }
  }

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'pending': return Colors.blue;
      case 'in_progress': return Colors.orange;
      case 'delivered': return colorScheme.primary;
      case 'reported': return colorScheme.error;
      case 'return_requested': return Colors.purple;
      case 'return_completed': return Colors.teal;
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }
}
