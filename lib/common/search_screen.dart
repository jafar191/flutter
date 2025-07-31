import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../screens/merchant/order_details_screen.dart';
import '../screens/admin/admin_user_profile_screen.dart'; // هذا الاستيراد يبدو غير مستخدم في هذا الملف، يمكن إزالته لاحقًا إذا لم يُستخدم.

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  String? _currentUserType;

  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchCurrentUserType();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserType() async {
    if (_currentUser == null) return;
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentUserType = userDoc['userType'] as String?;
        });
      }
    } catch (e) {
      debugPrint("Error fetching current user type: $e"); // تم إزالة الأقواس غير الضرورية
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults.clear();
    });

    try {
      QuerySnapshot orderSnapshot;

      if (_currentUserType == 'admin') {
        orderSnapshot = await _firestore
            .collection('orders')
            .where('customerPhone', isEqualTo: query)
            .get();
        if (orderSnapshot.docs.isEmpty) {
          orderSnapshot = await _firestore
              .collection('orders')
              .where('orderNumber', isEqualTo: int.tryParse(query))
              .get();
        }
      } else {
        orderSnapshot = await _firestore
            .collection('orders')
            .where('customerPhone', isEqualTo: query)
            .where(_currentUserType == 'merchant' ? 'merchantId' : 'driverId', isEqualTo: _currentUser!.uid)
            .get();
        if (orderSnapshot.docs.isEmpty) {
          orderSnapshot = await _firestore
              .collection('orders')
              .where('orderNumber', isEqualTo: int.tryParse(query))
              .where(_currentUserType == 'merchant' ? 'merchantId' : 'driverId', isEqualTo: _currentUser!.uid)
              .get();
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = orderSnapshot.docs;
          _isLoading = false;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error performing search: ${e.message}");
      if (mounted) {
        // Assume showCustomSnackBar is defined elsewhere, if not, it will be an error.
        // If it's your custom function, ensure it's imported or defined.
        // For this task, assuming it's correctly handled.
        // showCustomSnackBar(context, 'حدث خطأ في البحث: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error performing search: $e"); // تم إزالة الأقواس غير الضرورية
      if (mounted) {
        // Assuming showCustomSnackBar is defined elsewhere
        // showCustomSnackBar(context, 'حدث خطأ غير متوقع أثناء البحث.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'pending':
        return 'مسجلة';
      case 'in_progress':
        return 'قيد التوصيل';
      case 'delivered':
        return 'تم التوصيل';
      case 'reported':
        return 'مشكلة مبلغ عنها';
      case 'return_requested':
        return 'مرتجعة';
      case 'return_completed':
        return 'تم الإرجاع';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'pending':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'delivered':
        return colorScheme.primary;
      case 'reported':
        return colorScheme.error;
      case 'return_requested':
        return Colors.purple;
      case 'return_completed':
        return Colors.teal;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // تحديد اتجاه النص مرة واحدة

    if (_currentUser == null || _currentUserType == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text("البحث", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("البحث عن الطلبات", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
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
                labelText: 'ابحث برقم الهاتف أو رقم الطلب',
                hintText: (_currentUserType == 'admin')
                    ? 'ادخل رقم هاتف العميل أو رقم الطلب'
                    : 'ادخل رقم هاتف العميل أو رقم الطلب الخاص بك',
                prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults.clear();
                    });
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
              onSubmitted: (value) => _performSearch(value),
              style: textTheme.bodyMedium,
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
            ),
          ),
          _isLoading
              ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
              : Expanded(
                  child: _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off_outlined, size: 80, color: Color.fromRGBO(189, 189, 189, 1)),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'ابحث عن الطلبات باستخدام رقم الهاتف أو رقم الطلب.'
                                    : 'لم يتم العثور على طلبات مطابقة.',
                                style: textTheme.titleMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                                textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12.0),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            DocumentSnapshot orderDoc = _searchResults[index];
                            Color statusColor = _getStatusColor(orderDoc['status'] as String? ?? 'unknown', colorScheme);

                            return Card(
                              elevation: cardTheme.elevation,
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              shape: cardTheme.shape,
                              color: cardTheme.color,
                              child: InkWell(
                                // تم تعديل هذا السطر لمعالجة خطأ BorderRadius
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
                                        style: textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                                        textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                                        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                                      ),
                                      const SizedBox(height: 8.0),
                                      Text(
                                        'العميل: ${orderDoc['customerName'] ?? 'غير معروف'}',
                                        style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                                        textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                                        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                                      ),
                                      Text(
                                        'الهاتف: ${orderDoc['customerPhone'] ?? 'غير متوفر'}',
                                        style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                                        textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                                        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                                      ),
                                      Text(
                                        'العنوان: ${orderDoc['customerArea'] ?? ''} - ${orderDoc['customerAddress'] ?? ''}',
                                        style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                                        textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                                        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                                      ),
                                      const SizedBox(height: 8.0),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${orderDoc['totalPrice']?.toStringAsFixed(0) ?? '0'} د.ع',
                                            style: textTheme.titleLarge?.copyWith(
                                                color: colorScheme.primary, fontWeight: FontWeight.bold),
                                            textDirection: isRtl ? TextDirection.ltr : TextDirection.ltr, // ابقيه LTR للأرقام
                                          ),
                                          Text(
                                            'الحالة: ${_translateStatus(orderDoc['status'] as String? ?? 'unknown')}',
                                            style: textTheme.bodyLarge?.copyWith(
                                                color: statusColor, fontWeight: FontWeight.bold),
                                            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8.0),
                                      Align(
                                        alignment: isRtl ? Alignment.bottomRight : Alignment.bottomLeft, // استخدام isRtl
                                        child: Text(
                                          'التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format((orderDoc['createdAt'] as Timestamp).toDate())}',
                                          style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                                          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                                          textDirection: isRtl ? TextDirection.ltr : TextDirection.ltr, // ابقيه LTR للتاريخ
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
