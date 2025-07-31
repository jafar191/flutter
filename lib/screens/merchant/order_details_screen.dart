import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../../common/support_chat_screen.dart';
import '../admin/admin_user_profile_screen.dart';
import '../../common/custom_snackbar.dart'; // Assuming this file exists for showCustomSnackBar
// Assuming sendNotificationToAdmins is defined elsewhere (e.g., in custom_snackbar.dart or a utility file)
// If not, you will need to provide its implementation or import it.


class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _currentUser;
  String? _currentUserType;
  DocumentSnapshot? _orderDoc;
  String? _merchantName;
  String? _merchantPhone;
  String? _driverName;
  String? _driverPhone;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchUserDetails();
    _fetchOrderDetails();
  }

  Future<void> _fetchUserDetails() async {
    if (_currentUser == null) return;
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentUserType = userDoc['userType'] as String?;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching user details: ${e.message}");
    } catch (e) {
      debugPrint("Error fetching user details: $e"); // Removed unnecessary braces
    }
  }

  Future<void> _fetchOrderDetails() async {
    try {
      DocumentSnapshot doc = await _firestore.collection('orders').doc(widget.orderId).get();
      if (doc.exists && mounted) {
        setState(() {
          _orderDoc = doc;
        });
        _fetchRelatedUserNames();
      } else {
        if (mounted) { // Check for mounted
          showCustomSnackBar(context, 'لم يتم العثور على تفاصيل الطلب.', isError: true);
        }
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching order details: ${e.message}");
      if (mounted) { // Check for mounted
        showCustomSnackBar(context, 'حدث خطأ في جلب تفاصيل الطلب: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error fetching order details: $e"); // Removed unnecessary braces
      if (mounted) { // Check for mounted
        showCustomSnackBar(context, 'تعذر جلب تفاصيل الطلب.', isError: true);
      }
    }
  }

  Future<void> _fetchRelatedUserNames() async {
    if (!mounted || _orderDoc == null) return;

    if (_orderDoc!['merchantId'] != null) {
      try {
        DocumentSnapshot merchantDoc = await _firestore.collection('users').doc(_orderDoc!['merchantId'] as String).get();
        if (merchantDoc.exists && mounted) {
          setState(() {
            _merchantName = merchantDoc['name'] ?? merchantDoc['storeName'] ?? 'تاجر غير معروف';
            _merchantPhone = merchantDoc['phone'] ?? 'غير متوفر';
          });
        }
      } catch (e) {
        debugPrint("Error fetching merchant data: $e"); // Removed unnecessary braces
      }
    }

    if (_orderDoc!['driverId'] != null) {
      try {
        DocumentSnapshot driverDoc = await _firestore.collection('users').doc(_orderDoc!['driverId'] as String).get();
        if (driverDoc.exists && mounted) {
          setState(() {
            _driverName = driverDoc['name'] ?? 'مندوب غير معروف';
            _driverPhone = driverDoc['phone'] ?? 'غير متوفر';
          });
        }
      } catch (e) {
        debugPrint("Error fetching driver data: $e"); // Removed unnecessary braces
      }
    }
  }

  void _copyOrderId() {
    if (_orderDoc != null && _orderDoc!['orderNumber'] != null) {
      Clipboard.setData(ClipboardData(text: (_orderDoc!['orderNumber'] as num).toString()));
      if (mounted) { // Check for mounted
        showCustomSnackBar(context, 'تم نسخ رقم الطلب.', isSuccess: true);
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (!await launchUrl(launchUri)) {
      if (mounted) { // Check for mounted
        showCustomSnackBar(context, 'تعذر إجراء المكالمة.', isError: true);
      }
    }
  }

  Future<void> _updateOrderStatus(String newStatus, {String? reason, bool isReturnConfirmed = false}) async {
    if (_orderDoc == null || _currentUser == null) return;

    try {
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': _currentUser!.uid,
      };

      if (newStatus == 'in_progress' && _orderDoc!['inProgressAt'] == null) {
        updateData['inProgressAt'] = FieldValue.serverTimestamp();
        updateData['driverId'] = _currentUser!.uid;
      } else if (newStatus == 'delivered' && _orderDoc!['deliveredAt'] == null) {
        updateData['deliveredAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'reported') {
        updateData['reportedAt'] = FieldValue.serverTimestamp();
        updateData['reportReason'] = reason;
      } else if (newStatus == 'cancelled') {
        updateData['cancelledAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'return_completed') {
        updateData['returnCompletedAt'] = FieldValue.serverTimestamp();
        updateData['isReturnConfirmedByMerchant'] = isReturnConfirmed;
      }

      await _firestore.collection('orders').doc(widget.orderId).update(updateData);
      if (mounted) { // Check for mounted
        showCustomSnackBar(context, 'تم تحديث حالة الطلب بنجاح إلى ${_translateStatus(newStatus)}!', isSuccess: true);
        _fetchOrderDetails();
      }

      _sendOrderUpdateNotifications(newStatus, reason);

    } on FirebaseException catch (e) {
      debugPrint("Firebase Error updating order status: ${e.message}");
      if (mounted) { // Check for mounted
        showCustomSnackBar(context, 'حدث خطأ في Firebase أثناء تحديث الحالة: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error updating order status: $e"); // Removed unnecessary braces
      if (mounted) { // Check for mounted
        showCustomSnackBar(context, 'حدث خطأ غير متوقع أثناء تحديث الحالة.', isError: true);
      }
    }
  }

  Future<void> _sendOrderUpdateNotifications(String newStatus, String? reason) async {
    String? merchantId = _orderDoc!['merchantId'] as String?;
    String? driverId = _orderDoc!['driverId'] as String?;
    String orderNumber = (_orderDoc!['orderNumber'] as num?)?.toString() ?? widget.orderId;

    if (merchantId != null) {
      String title = 'تحديث حالة طلبك #$orderNumber';
      String body = 'حالة طلبك #$orderNumber تغيرت إلى ${_translateStatus(newStatus)}.';
      if (newStatus == 'reported') {
        body = 'هناك مشكلة في طلبك #$orderNumber: ${reason ?? 'غير مذكور'}. يرجى التواصل مع الدعم.';
      } else if (newStatus == 'delivered') {
        body = 'تم توصيل طلبك #$orderNumber بنجاح. يرجى مراجعة تفاصيله.';
      }
      await _firestore.collection('notifications').add({
        'userId': merchantId,
        'title': title,
        'body': body,
        'type': 'order_status_update',
        'relatedOrderId': widget.orderId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (driverId != null && driverId != _currentUser!.uid) {
      String title = 'تحديث حالة طلب #$orderNumber';
      String body = 'الطلب #$orderNumber تم تحديث حالته إلى ${_translateStatus(newStatus)}.';
      await _firestore.collection('notifications').add({
        'userId': driverId,
        'title': title,
        'body': body,
        'type': 'order_status_update',
        'relatedOrderId': widget.orderId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Assuming sendNotificationToAdmins is defined elsewhere (e.g., in custom_snackbar.dart or a utility file)
    await sendNotificationToAdmins(
      _firestore,
      'تحديث طلب #$orderNumber',
      'تم تحديث حالة الطلب #$orderNumber إلى ${_translateStatus(newStatus)} بواسطة ${_currentUserType == 'merchant' ? 'التاجر' : _currentUserType == 'driver' ? 'المندوب' : 'المسؤول'}.',
      type: 'order_update',
      relatedOrderId: widget.orderId,
      senderId: _currentUser!.uid,
      senderName: _currentUserType == 'merchant' ? _merchantName : (_currentUserType == 'driver' ? _driverName : 'المسؤول'),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    List<Widget> buttons = [];
    if (_orderDoc == null || _currentUserType == null) return buttons;

    String status = _orderDoc!['status'] as String? ?? 'unknown';

    if (_currentUserType == 'merchant' && _orderDoc!['merchantId'] == _currentUser!.uid) {
      if (status == 'pending') {
        buttons.add(Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _confirmCancelOrder(),
            icon: const Icon(Icons.cancel, color: Colors.white),
            label: const Text('إلغاء الطلب', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          ),
        ));
      } else if (status == 'reported') {
        buttons.add(Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus('pending'),
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text('معالجة المشكلة', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
          ),
        ));
        buttons.add(const SizedBox(width: 8));
        buttons.add(Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus('return_requested'),
            icon: const Icon(Icons.assignment_return, color: Colors.white),
            label: const Text('طلب إرجاع', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary),
          ),
        ));
      }
      if ((status == 'delivered' || status == 'return_completed') && (_orderDoc!['isRated'] ?? false) == false && _orderDoc!['driverId'] != null) {
        buttons.add(const SizedBox(width: 8));
        buttons.add(Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              if (mounted) { // Check for mounted
                showCustomSnackBar(context, "الرجاء تطوير شاشة تقييم المندوب", isError: false);
              }
              debugPrint("تقييم المندوب");
            },
            icon: const Icon(Icons.star, color: Colors.white),
            label: const Text('تقييم المندوب', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
          ),
        ));
      }
    }
    else if (_currentUserType == 'driver' && _orderDoc!['driverId'] == _currentUser!.uid) {
      if (status == 'pending') {
        buttons.add(Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus('in_progress'),
            icon: const Icon(Icons.delivery_dining, color: Colors.white),
            label: const Text('استلام الطلب', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
          ),
        ));
        buttons.add(const SizedBox(width: 8));
      }
      if (status == 'in_progress' || status == 'reported') {
        buttons.add(Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showDeliveryConfirmationDialog(context),
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            label: const Text('تم التوصيل', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ));
      }
      if (status == 'pending' || status == 'in_progress') {
        buttons.add(const SizedBox(width: 8));
        buttons.add(Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showReportProblemBottomSheet(context),
            icon: const Icon(Icons.warning_amber, color: Colors.white),
            label: const Text('تبليغ عن مشكلة', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          ),
        ));
      }
      if (status == 'return_requested') {
        buttons.add(Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus('return_completed', isReturnConfirmed: true),
            icon: const Icon(Icons.assignment_return, color: Colors.white),
            label: const Text('تأكيد الإرجاع', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary),
          ),
        ));
      }
    }
    else if (_currentUserType == 'admin') {
      buttons.add(Expanded(
        child: ElevatedButton.icon(
          onPressed: () {
            if (mounted) { // Check for mounted
              showCustomSnackBar(context, "الرجاء تطوير شاشة التحكم الإداري للطلب", isError: false);
            }
            debugPrint("تحكم إداري للطلب");
          },
          icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
          label: const Text('تحكم إداري', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
        ),
      ));
    }
    return buttons;
  }

  void _confirmCancelOrder() {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // Define isRtl
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text("تأكيد إلغاء الطلب", style: Theme.of(ctx).textTheme.titleLarge?.copyWith(color: Theme.of(ctx).colorScheme.onSurface), textAlign: isRtl ? TextAlign.right : TextAlign.left),
        content: Text("هل أنت متأكد من إلغاء هذا الطلب؟ لا يمكن التراجع عن هذا الإجراء.", style: Theme.of(ctx).textTheme.bodyMedium, textAlign: isRtl ? TextAlign.right : TextAlign.left),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("إلغاء", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Theme.of(ctx).colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateOrderStatus('cancelled');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text("تأكيد الإلغاء", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeliveryConfirmationDialog(BuildContext context) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // Define isRtl
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text("تأكيد التوصيل", style: Theme.of(ctx).textTheme.titleLarge?.copyWith(color: Theme.of(ctx).colorScheme.onSurface), textAlign: isRtl ? TextAlign.right : TextAlign.left),
        content: Text("هل أنت متأكد من أن الطلب قد تم توصيله بنجاح؟", style: Theme.of(ctx).textTheme.bodyMedium, textAlign: isRtl ? TextAlign.right : TextAlign.left),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("إلغاء", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Theme.of(ctx).colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateOrderStatus('delivered');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.primary),
            child: Text("تأكيد", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReportProblemBottomSheet(BuildContext context) {
    final TextEditingController notesController = TextEditingController();
    String? selectedReason;
    final List<String> reasons = [
      'تغيير سعر', 'مغلق', 'مغلق بعد الاتفاق', 'لا يرد', 'لا يرد بعد الاتفاق',
      'الرقم غير داخل في الخدمة', 'لا يمكن الاتصال به', 'مؤجل', 'مؤجل لحين إعادة الطلب لاحقاً',
      'إلغاء الطلب', 'رفض الطلب', 'لم يطلب', 'عنوان غير صحيح', 'منطقة خطيرة أو غير آمنة',
      'الطلب تالف أو مكسور', 'الطلب ناقص أو غير مكتمل', 'الطلب لا يطابق المواصفات المطلوبة'
    ];
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // Define isRtl

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bc) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateB) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(bc).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft, // Use isRtl
                      child: Text("التبليغ عن مشكلة", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      items: reasons.map((String reason) {
                        return DropdownMenuItem<String>(
                          value: reason,
                          child: Text(reason, style: Theme.of(context).textTheme.bodyMedium, textDirection: TextDirection.rtl),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setStateB(() {
                          selectedReason = newValue;
                        });
                      },
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                      icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
                      isExpanded: true,
                      menuMaxHeight: MediaQuery.of(context).size.height * 0.4,
                      decoration: InputDecoration(
                        labelText: 'سبب التبليغ الرئيسي',
                        hintText: 'اختر سبباً',
                        filled: Theme.of(context).inputDecorationTheme.filled,
                        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                        border: Theme.of(context).inputDecorationTheme.border,
                        enabledBorder: Theme.of(context).inputDecorationTheme.enabledBorder,
                        focusedBorder: Theme.of(context).inputDecorationTheme.focusedBorder,
                        labelStyle: Theme.of(context).inputDecorationTheme.labelStyle,
                        hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                        contentPadding: Theme.of(context).inputDecorationTheme.contentPadding,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات إضافية (اختياري)',
                        hintText: 'اكتب تفاصيل إضافية هنا...',
                        filled: Theme.of(context).inputDecorationTheme.filled,
                        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                        border: Theme.of(context).inputDecorationTheme.border,
                        enabledBorder: Theme.of(context).inputDecorationTheme.enabledBorder,
                        focusedBorder: Theme.of(context).inputDecorationTheme.focusedBorder,
                        labelStyle: Theme.of(context).inputDecorationTheme.labelStyle,
                        hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                        contentPadding: Theme.of(context).inputDecorationTheme.contentPadding,
                      ),
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
                      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(bc),
                          child: Text('إلغاء', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (selectedReason == null) {
                              if (mounted) { // Check for mounted
                                showCustomSnackBar(context, 'الرجاء اختيار سبب التبليغ.', isError: true);
                              }
                              return;
                            }
                            Navigator.pop(bc);
                            _updateOrderStatus('reported', reason: selectedReason! + (notesController.text.isNotEmpty ? ' - ${notesController.text}' : ''));
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                          child: Text('إرسال التبليغ', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)),
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


  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // Define isRtl

    if (_orderDoc == null || _currentUserType == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text("تفاصيل الطلب", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _copyOrderId,
          child: Text(
            'طلب رقم: #${_orderDoc!['orderNumber'] ?? _orderDoc!.id}',
            style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
            textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_orderDoc!['customerPhone'] != null)
            IconButton(
              icon: Icon(Icons.phone, color: colorScheme.onSurface),
              onPressed: () => _makePhoneCall(_orderDoc!['customerPhone'] as String),
              tooltip: 'الاتصال بـ ${_orderDoc!['customerPhone'] as String}', // Removed unnecessary braces
            ),
          IconButton(
            icon: Icon(Icons.chat, color: colorScheme.onSurface),
            onPressed: () {
              String? targetId;
              String? targetName;

              if (_currentUserType == 'merchant') {
                targetId = _orderDoc!['driverId'] as String?;
                targetName = _driverName;
              } else if (_currentUserType == 'driver') {
                targetId = _orderDoc!['merchantId'] as String?;
                targetName = _merchantName;
              } else if (_currentUserType == 'admin') {
                if (_orderDoc!['merchantId'] != null) {
                  targetId = _orderDoc!['merchantId'] as String?;
                  targetName = _merchantName;
                } else if (_orderDoc!['driverId'] != null) {
                  targetId = _orderDoc!['driverId'] as String?;
                  targetName = _driverName;
                } else {
                  if (mounted) { // Check for mounted
                    showCustomSnackBar(context, 'لا يوجد طرف آخر متاح للدردشة.', isError: true);
                  }
                  return;
                }
              }

              if (targetId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SupportChatScreen(
                      targetUserId: targetId,
                      targetUserName: targetName,
                    ),
                  ),
                );
              } else {
                if (mounted) { // Check for mounted
                  showCustomSnackBar(context, 'لا يوجد طرف متاح للدردشة لهذا الطلب.', isError: true);
                }
              }
            },
            tooltip: 'تواصل بشأن الطلب',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionHeader("تفاصيل العميل والمستلم", isRtl), // Pass isRtl
                  _buildDetailRow(context, "الاسم:", _orderDoc!['customerName'] as String? ?? 'غير متوفر', isRtl: isRtl), // Pass isRtl
                  _buildDetailRowWithCall(context, "الهاتف:", _orderDoc!['customerPhone'] as String, isRtl: isRtl), // Pass isRtl (Removed unnecessary cast)
                  if (_orderDoc!['customerSecondaryPhone'] != null && (_orderDoc!['customerSecondaryPhone'] as String).isNotEmpty)
                    _buildDetailRowWithCall(context, "هاتف ثانوي:", _orderDoc!['customerSecondaryPhone'] as String, isRtl: isRtl), // Pass isRtl
                  _buildDetailRow(context, "العنوان:", '${_orderDoc!['customerArea'] ?? ''} - ${_orderDoc!['customerAddress'] ?? ''}', isRtl: isRtl), // Pass isRtl

                  _buildSectionHeader("تفاصيل البضاعة", isRtl), // Pass isRtl
                  _buildDetailRow(context, "نوع البضاعة:", _orderDoc!['goodsType'] as String? ?? 'غير متوفر', isRtl: isRtl), // Pass isRtl
                  _buildDetailRow(context, "العدد:", (_orderDoc!['quantity']?.toString() ?? 'غير متوفر'), isRtl: isRtl), // Pass isRtl (Removed unnecessary cast)
                  if (_orderDoc!['notes'] != null && (_orderDoc!['notes'] as String).isNotEmpty)
                    _buildDetailRow(context, "ملاحظات الطلب:", _orderDoc!['notes'] as String, isRtl: isRtl), // Pass isRtl

                  _buildSectionHeader("معلومات الطلب الأساسية", isRtl), // Pass isRtl
                  _buildDetailRow(context, "المبلغ الكلي:", '${_orderDoc!['totalPrice']?.toStringAsFixed(0) ?? '0'} د.ع', isPrice: true, isRtl: isRtl), // Pass isRtl
                  _buildDetailRow(context, "الحالة:", _translateStatus(_orderDoc!['status'] as String? ?? 'unknown'), statusColor: _getStatusColor(_orderDoc!['status'] as String? ?? 'unknown', colorScheme), isRtl: isRtl), // Pass isRtl
                  _buildDetailRow(context, "تاريخ الإنشاء:", DateFormat('yyyy-MM-dd HH:mm').format((_orderDoc!['createdAt'] as Timestamp).toDate()), isRtl: isRtl), // Pass isRtl

                  if (_currentUserType == 'admin' || _currentUserType == 'driver')
                    if (_orderDoc!['merchantId'] != null)
                      _buildUserCard(context, 'التاجر', _merchantName, _merchantPhone, _orderDoc!['merchantId'] as String, isRtl), // Pass isRtl

                  if (_currentUserType == 'admin' || _currentUserType == 'merchant')
                    if (_orderDoc!['driverId'] != null)
                      _buildUserCard(context, 'المندوب', _driverName, _driverPhone, _orderDoc!['driverId'] as String, isRtl), // Pass isRtl

                  _buildSectionHeader("سجل حالة الطلب", isRtl), // Pass isRtl
                  _buildOrderStatusTimeline(context, isRtl), // Pass isRtl
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((255 * 0.1).round()), // Use .withAlpha instead of .withOpacity
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: _buildActionButtons(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isRtl) { // Added isRtl parameter
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Align(
        alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft, // Use isRtl
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isPrice = false, Color? statusColor, required bool isRtl}) { // Added isRtl parameter
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isRtl ? MainAxisAlignment.end : MainAxisAlignment.start, // Use isRtl
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyLarge?.copyWith(
                color: isPrice ? colorScheme.primary : statusColor ?? colorScheme.onSurface,
                fontWeight: isPrice ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
            ),
          ),
          const SizedBox(width: 8.0),
          Text(
            label,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: const Color.fromRGBO(117, 117, 117, 1)),
            textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithCall(BuildContext context, String label, String phoneNumber, {required bool isRtl}) { // Added isRtl parameter
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isRtl ? MainAxisAlignment.end : MainAxisAlignment.start, // Use isRtl
        children: [
          IconButton(
            icon: Icon(Icons.phone, color: colorScheme.primary),
            onPressed: () => _makePhoneCall(phoneNumber),
            tooltip: 'الاتصال بـ $phoneNumber', // Removed unnecessary braces
          ),
          Text(
            phoneNumber,
            style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
            textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
          ),
          const SizedBox(width: 8.0),
          Text(
            label,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: const Color.fromRGBO(117, 117, 117, 1)),
            textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, String role, String? name, String? phone, String userId, bool isRtl) { // Added isRtl parameter
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme;

    return Card(
      elevation: cardTheme.elevation,
      shape: cardTheme.shape,
      color: cardTheme.color,
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // Use isRtl
          children: [
            Text(
              'معلومات $role',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // Use isRtl
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
            ),
            const SizedBox(height: 8),
            _buildDetailRow(context, 'الاسم:', name ?? 'غير متوفر', isRtl: isRtl), // Pass isRtl
            _buildDetailRowWithCall(context, 'الهاتف:', phone ?? 'غير متوفر', isRtl: isRtl), // Pass isRtl
            Align(
              alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight, // Use isRtl
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AdminUserProfileScreen(userId: userId)));
                },
                icon: Icon(Icons.person, color: colorScheme.primary),
                label: Text('عرض ملف $role', style: textTheme.labelLarge?.copyWith(color: colorScheme.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusTimeline(BuildContext context, bool isRtl) { // Added isRtl parameter
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final Map<String, DateTime?> statusTimes = {
      'pending': (_orderDoc!['createdAt'] as Timestamp?)?.toDate(),
      'in_progress': (_orderDoc!['inProgressAt'] as Timestamp?)?.toDate(),
      'delivered': (_orderDoc!['deliveredAt'] as Timestamp?)?.toDate(),
      'reported': (_orderDoc!['reportedAt'] as Timestamp?)?.toDate(),
      'cancelled': (_orderDoc!['cancelledAt'] as Timestamp?)?.toDate(),
      'return_requested': (_orderDoc!['returnRequestedAt'] as Timestamp?)?.toDate(),
      'return_completed': (_orderDoc!['returnCompletedAt'] as Timestamp?)?.toDate(),
    };

    final List<String> mainStatusesOrder = [
      'pending', 'in_progress', 'delivered', 'reported', 'cancelled', 'return_requested', 'return_completed',
    ];

    return Column(
      crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // Use isRtl
      children: mainStatusesOrder.map((statusKey) {
        final DateTime? statusTime = statusTimes[statusKey];
        if (statusTime == null && statusKey != (_orderDoc!['status'] as String? ?? '')) {
          return const SizedBox.shrink();
        }

        final bool isCurrentStatus = statusKey == (_orderDoc!['status'] as String? ?? '');
        final Color circleColor = isCurrentStatus ? colorScheme.primary : (statusTime != null ? Colors.green : const Color.fromRGBO(189, 189, 189, 1));
        final Color lineColor = statusTime != null ? const Color.fromRGBO(76, 175, 80, 0.7) : const Color.fromRGBO(224, 224, 224, 1);
        final String statusLabel = _translateStatus(statusKey);
        final String timeLabel = statusTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(statusTime) : 'لم يتم بعد';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Ensure row direction is correct
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      statusTime != null ? Icons.check : Icons.circle_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                if (statusKey != mainStatusesOrder.last)
                  Container(
                    width: 2,
                    height: 50,
                    color: lineColor,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Column(
                  crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // Use isRtl
                  children: [
                    Text(
                      statusLabel,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isCurrentStatus ? colorScheme.primary : colorScheme.onSurface,
                      ),
                      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
                    ),
                    Text(
                      timeLabel,
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color.fromRGBO(117, 117, 117, 1),
                      ),
                      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
                    ),
                    if (statusKey == 'reported' && _orderDoc!['reportReason'] != null && (_orderDoc!['reportReason'] as String).isNotEmpty)
                      Text(
                        'السبب: ${_orderDoc!['reportReason']}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                          fontStyle: FontStyle.italic,
                        ),
                        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // Use isRtl
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
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