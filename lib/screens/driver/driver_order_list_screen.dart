import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../merchant/order_details_screen.dart';
import '../admin/admin_user_profile_screen.dart'; // هذا الاستيراد يبدو غير مستخدم بشكل مباشر هنا.
import '../../common/custom_snackbar.dart'; // افتراض وجود showCustomSnackBar


class DriverOrderListScreen extends StatefulWidget {
  final String status;
  final String title;
  final String? userId;
  final String? userType;

  const DriverOrderListScreen({
    super.key,
    required this.status,
    required this.title,
    this.userId,
    this.userType,
  });

  @override
  State<DriverOrderListScreen> createState() => _DriverOrderListScreenState();
}

class _DriverOrderListScreenState extends State<DriverOrderListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  String? _currentUserType;

  late final Map<String, String> _merchantNames; // تم جعلها final و late

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _merchantNames = {}; // تهيئة الخريطة
    _fetchCurrentUserTypeAndNames();
  }

  Future<void> _fetchCurrentUserTypeAndNames() async {
    if (_currentUser == null) return;

    try {
      DocumentSnapshot currentUserDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (currentUserDoc.exists && mounted) {
        setState(() {
          _currentUserType = currentUserDoc['userType'] as String?;
        });
      }

      QuerySnapshot usersSnapshot = await _firestore.collection('users').where('userType', isEqualTo: 'merchant').get();
      final Map<String, String> names = {};
      for (var doc in usersSnapshot.docs) {
        names[doc.id] = doc['name'] ?? doc['storeName'] ?? 'غير معروف';
      }
      if (mounted) {
        setState(() {
          _merchantNames = names;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching user data: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ في Firebase أثناء جلب بيانات المستخدمين: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e"); // إزالة الأقواس غير الضرورية
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'تعذر جلب بيانات المستخدمين.', isError: true);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // لتحديد اتجاه النص

    if (_currentUser == null || _currentUserType == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title, style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    Query query = _firestore.collection('orders');

    if (widget.userId != null && widget.userType != null) {
      if (widget.userType == 'merchant') {
        query = query.where('merchantId', isEqualTo: widget.userId);
      } else if (widget.userType == 'driver') {
        query = query.where('driverId', isEqualTo: widget.userId);
      }
    } else {
      if (_currentUserType == 'merchant') {
        query = query.where('merchantId', isEqualTo: _currentUser!.uid);
      } else if (_currentUserType == 'driver') {
        query = query.where('driverId', isEqualTo: _currentUser!.uid);
      } else if (_currentUserType == 'admin') {
        // إذا كان المستخدم الحالي مسؤول، فلا تُطبق فلترة حسب user.uid
        // يمكن تركها فارغة أو إضافة فلتر عام للطلبات هنا
      }
    }

    if (widget.status != 'all') {
      query = query.where('status', isEqualTo: widget.status);
    }

    query = query.orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: colorScheme.primary));
          }
          if (snapshot.hasError) {
            debugPrint("Order List Stream Error: ${snapshot.error}");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'حدث خطأ في جلب الطلبات: ${snapshot.error}',
                  style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
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
                    'لا توجد طلبات في قسم "${widget.title}" حالياً.',
                    style: textTheme.titleMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                    textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot orderDoc = snapshot.data!.docs[index];

              String merchantName = _merchantNames[orderDoc['merchantId']] ?? 'تاجر غير معروف';
              // Fixed: Access driver name directly, not from _merchantNames
              String driverName = orderDoc['driverId'] != null ? (orderDoc['driverName'] ?? 'لم يتم التعيين بعد') : 'لم يتم التعيين بعد';


              Color statusColor = _getStatusColor(orderDoc['status'] as String? ?? 'unknown', colorScheme);

              return Card(
                elevation: cardTheme.elevation,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: cardTheme.shape,
                color: cardTheme.color,
                child: InkWell(
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
                      crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // استخدام isRtl
                      children: [
                        Text(
                          'طلب رقم: #${orderDoc['orderNumber'] ?? orderDoc.id}',
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                        ),
                        const SizedBox(height: 8.0),
                        if (orderDoc['customerName'] != null && (orderDoc['customerName'] as String).isNotEmpty)
                          Text(
                            'العميل: ${orderDoc['customerName']}',
                            style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                          ),
                        if (orderDoc['customerArea'] != null && (orderDoc['customerArea'] as String).isNotEmpty ||
                            orderDoc['customerAddress'] != null && (orderDoc['customerAddress'] as String).isNotEmpty)
                          Text(
                            'العنوان: ${orderDoc['customerArea'] ?? ''} - ${orderDoc['customerAddress'] ?? ''}',
                            style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                          ),
                        const SizedBox(height: 4.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${orderDoc['totalPrice']?.toStringAsFixed(0) ?? '0'} د.ع',
                              style: textTheme.titleLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                              textDirection: TextDirection.ltr, // يفضل LTR للأرقام
                            ),
                            Text(
                              'الحالة: ${_translateStatus(orderDoc['status'] as String? ?? 'unknown')}',
                              style: textTheme.bodyLarge?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                            ),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        if (_currentUserType == 'admin' || _currentUserType == 'driver')
                          if (orderDoc['merchantId'] != null && (orderDoc['merchantId'] as String).isNotEmpty)
                            Text(
                              'التاجر: $merchantName',
                              style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                            ),
                        if (_currentUserType == 'admin' || _currentUserType == 'merchant')
                          if (orderDoc['driverId'] != null && (orderDoc['driverId'] as String).isNotEmpty)
                            Text(
                              'المندوب: $driverName',
                              style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                            ),
                        const SizedBox(height: 8.0),
                        Align(
                          alignment: isRtl ? Alignment.bottomRight : Alignment.bottomLeft, // استخدام isRtl
                          child: Text(
                            'التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format((orderDoc['createdAt'] as Timestamp).toDate())}',
                            style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                            textDirection: TextDirection.ltr, // يفضل LTR للتاريخ/الوقت
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