import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'driver_settlement_history_screen.dart'; // هذا الاستيراد يجب أن يكون لـ DriverSettlementHistoryScreen
import '../../common/custom_snackbar.dart'; // افتراض وجود showCustomSnackBar و sendNotificationToAdmins
// Future<void> sendNotificationToAdmins(...) // تأكد من توفر هذه الدالة


class DriverSettlementScreen extends StatefulWidget {
  // تم تصحيح اسم الفئة والمُنشئ ليتوافق مع الاتفاقيات
  const DriverSettlementScreen({super.key});

  @override
  State<DriverSettlementScreen> createState() => _DriverSettlementScreenState();
}

class _DriverSettlementScreenState extends State<DriverSettlementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  double _totalEarnings = 0.0;
  double _totalCashCollected = 0.0;
  double _balanceDue = 0.0;
  List<DocumentSnapshot> _unsettledOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchSettlementData();
  }

  Future<void> _fetchSettlementData() async {
    if (!mounted || _currentUser == null) return;

    setState(() { _isLoading = true; });

    try {
      DateTime startOfToday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      QuerySnapshot ordersSnapshot = await _firestore
          .collection('orders')
          .where('driverId', isEqualTo: _currentUser!.uid)
          .where('status', isEqualTo: 'delivered')
          .where('deliveredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .where('isSettledDriver', isEqualTo: false)
          .orderBy('deliveredAt', descending: true)
          .get();

      double earnings = 0.0;
      double cashCollected = 0.0;
      List<DocumentSnapshot> unsettled = [];

      for (var doc in ordersSnapshot.docs) {
        earnings += (doc['driverEarnings'] as num?)?.toDouble() ?? 1500.0;
        cashCollected += (doc['totalPrice'] as num?)?.toDouble() ?? 0.0;
        unsettled.add(doc);
      }

      if (mounted) {
        setState(() {
          _totalEarnings = earnings;
          _totalCashCollected = cashCollected;
          _balanceDue = cashCollected - earnings;
          _unsettledOrders = unsettled;
          _isLoading = false;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching settlement data: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isLoading = false; });
        showCustomSnackBar(context, 'حدث خطأ في Firebase عند جلب بيانات التحاسب: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error fetching settlement data: $e"); // إزالة الأقواس
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isLoading = false; });
        showCustomSnackBar(context, 'حدث خطأ عند جلب بيانات التحاسب.', isError: true);
      }
    }
  }

  Future<void> _requestSettlement() async {
    if (!mounted || _currentUser == null || _unsettledOrders.isEmpty) return;

    if (_balanceDue == 0.0) {
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'لا توجد مبالغ مستحقة للتحاسب.', isError: true);
      }
      return;
    }

    setState(() { _isLoading = true; });

    try {
      List<String> orderIds = _unsettledOrders.map((doc) => doc.id).toList();
      String driverName = (await _firestore.collection('users').doc(_currentUser!.uid).get())['name'] ?? 'مندوب غير معروف';

      DocumentReference settlementRef = await _firestore.collection('settlements').add({
        'userId': _currentUser!.uid,
        'userType': 'driver',
        'userName': driverName,
        'date': FieldValue.serverTimestamp(),
        'totalAmount': _balanceDue,
        'orderIds': orderIds,
        'status': 'pending_admin_approval',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // افتراض أن دالة sendNotificationToAdmins مُعرّفة ومُتاحة
      await sendNotificationToAdmins(
        _firestore,
        'طلب تحاسب جديد من مندوب',
        // إزالة الأقواس
        'المندوب $driverName (ID: ${_currentUser!.uid}) طلب تحاسباً بمبلغ ${_balanceDue.toStringAsFixed(0)} دينار.',
        type: 'new_settlement_request',
        relatedSettlementId: settlementRef.id,
        senderId: _currentUser!.uid,
        senderName: driverName,
      );

      WriteBatch batch = _firestore.batch();
      for (var orderDoc in _unsettledOrders) {
        batch.update(orderDoc.reference, {
          'isSettledDriver': true,
          'settlementId': settlementRef.id,
          'settledAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'تم إرسال طلب التحاسب بنجاح. سيتم مراجعته من قبل الإدارة.', isSuccess: true);
        await _fetchSettlementData();
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error requesting settlement: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ في Firebase عند إرسال طلب التحاسب: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error requesting settlement: $e"); // إزالة الأقواس
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ غير متوقع عند إرسال طلب التحاسب.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // لتحديد اتجاه النص


    if (_currentUser == null || _isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text("المحاسبة", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("المحاسبة", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader("ملخص التحاسب", isRtl), // تمرير isRtl
            _buildSummaryCard(textTheme, colorScheme, cardTheme, isRtl), // تمرير isRtl

            const SizedBox(height: 24.0),
            _buildSectionHeader("الطلبات غير المحاسب عليها", isRtl), // تمرير isRtl
            _unsettledOrders.isEmpty
                ? Center(
                  child: Column(
                    children: [
                      const Icon(Icons.assignment_turned_in_outlined, size: 60, color: Color.fromRGBO(189, 189, 189, 1)),
                      const SizedBox(height: 8),
                      Text('لا توجد طلبات غير محاسب عليها حالياً.', style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)), textAlign: isRtl ? TextAlign.right : TextAlign.left,), // استخدام isRtl
                    ],
                  ),
                )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _unsettledOrders.length,
                    itemBuilder: (context, index) {
                      DocumentSnapshot order = _unsettledOrders[index];
                      // تأكد من أن driverEarnings موجود
                      double companySharePerOrder = ((order['totalPrice'] as num?) ?? 0.0) - ((order['driverEarnings'] as num?)?.toDouble() ?? 0.0);
                      return Card(
                        elevation: cardTheme.elevation,
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        shape: cardTheme.shape,
                        color: cardTheme.color,
                        child: ListTile(
                          title: Text(
                            'طلب رقم: #${order['orderNumber'] ?? order.id}',
                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                          ),
                          subtitle: Text(
                            'المبلغ المستلم: ${order['totalPrice']?.toStringAsFixed(0) ?? '0'} د.ع | أرباحك: ${order['driverEarnings']?.toStringAsFixed(0) ?? '0'} د.ع',
                            style: textTheme.bodySmall?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                          ),
                          trailing: Text(
                            'لـ الشركة: ${companySharePerOrder.toStringAsFixed(0)} د.ع',
                            style: textTheme.titleMedium?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold),
                            textDirection: TextDirection.ltr, // يفضل LTR للأرقام
                          ),
                          onTap: () {
                            // يمكنك إضافة Navigator.push هنا لعرض تفاصيل الطلب
                          },
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24.0),
            _isLoading
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : ElevatedButton(
                    onPressed: _unsettledOrders.isEmpty ? null : _requestSettlement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      disabledBackgroundColor: const Color.fromRGBO(224, 224, 224, 1),
                    ),
                    child: Text(
                      _unsettledOrders.isEmpty ? 'لا توجد طلبات للتحاسب عليها' : 'طلب التحاسب الآن',
                      style: textTheme.labelLarge?.copyWith(color: _unsettledOrders.isEmpty ? const Color.fromRGBO(117, 117, 117, 1) : colorScheme.onPrimary),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // تم تعديل الدالة لقبول isRtl
  Widget _buildSectionHeader(String title, bool isRtl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Align(
        alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft, // استخدام isRtl
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        ),
      ),
    );
  }

  // تم تعديل الدالة لقبول isRtl
  Widget _buildSummaryCard(TextTheme textTheme, ColorScheme colorScheme, CardTheme cardTheme, bool isRtl) {
    return Card(
      elevation: cardTheme.elevation,
      shape: cardTheme.shape,
      color: cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // استخدام isRtl
          children: [
            _buildSummaryRow(textTheme, colorScheme, 'إجمالي الأرباح المستحقة:', '${_totalEarnings.toStringAsFixed(0)} د.ع', colorScheme.primary, isRtl), // تمرير isRtl
            _buildSummaryRow(textTheme, colorScheme, 'إجمالي المبالغ المحصلة:', '${_totalCashCollected.toStringAsFixed(0)} د.ع', Colors.orange, isRtl), // تمرير isRtl
            const Divider(height: 30, thickness: 1),
            _buildSummaryRow(textTheme, colorScheme, 'الرصيد المطلوب تسليمه:', '${_balanceDue.toStringAsFixed(0)} د.ع', _balanceDue >= 0 ? colorScheme.error : Colors.green, isRtl), // تمرير isRtl
          ],
        ),
      ),
    );
  }

  // تم تعديل الدالة لقبول isRtl
  Widget _buildSummaryRow(TextTheme textTheme, ColorScheme colorScheme, String label, String value, Color valueColor, bool isRtl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
            textDirection: TextDirection.ltr, // يفضل LTR للأرقام
          ),
          Text(
            label,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
          ),
        ],
      ),
    );
  }
}