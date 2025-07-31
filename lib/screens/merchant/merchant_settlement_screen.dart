import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'merchant_settlement_history_screen.dart';
// هذا الاستيراد غير مستخدم بشكل مباشر هنا في MerchantSettlementScreen
// import '../admin/admin_user_profile_screen.dart';
// افتراض وجود showCustomSnackBar و sendNotificationToAdmins في common/custom_snackbar.dart وملف آخر
import '../../common/custom_snackbar.dart';
// بما أن sendNotificationToAdmins مستخدمة، سأفترض أنها في ملف منفصل أو تم تعريفها سابقًا
// وإلا، ستحتاج إلى توفير تعريفها أو استيرادها من مكانها الصحيح.
// Future<void> sendNotificationToAdmins(...)

class MerchantSettlementScreen extends StatefulWidget {
  const MerchantSettlementScreen({super.key});

  @override
  State<MerchantSettlementScreen> createState() => _MerchantSettlementScreenState();
}

class _MerchantSettlementScreenState extends State<MerchantSettlementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  List<DocumentSnapshot> _unsettledOrders = [];
  double _totalAmountDue = 0.0;
  bool _isLoading = false;
  bool _isRequestingSettlement = false;


  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _fetchUnsettledOrders();
    }
  }

  Future<void> _fetchUnsettledOrders() async {
    if (!mounted || _currentUser == null) return;

    setState(() { _isLoading = true; });

    try {
      QuerySnapshot ordersSnapshot = await _firestore
          .collection('orders')
          .where('merchantId', isEqualTo: _currentUser!.uid)
          .where('status', isEqualTo: 'delivered')
          .where('isSettledMerchant', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      double total = 0.0;
      for (var doc in ordersSnapshot.docs) {
        double orderPrice = (doc['totalPrice'] as num?)?.toDouble() ?? 0.0;
        // افتراض أن 2000.0 هي حصة الشركة الثابتة لكل طلب
        // إذا كانت حصة الشركة تُجلب من Firestore (مثل doc['companyShare'])،
        // فيجب استخدام تلك القيمة بدلاً من 2000.0 الثابتة.
        double companyShare = (doc['companyShare'] as num?)?.toDouble() ?? 0.0;
        total += (orderPrice - companyShare);
      }

      if (mounted) {
        setState(() {
          _unsettledOrders = ordersSnapshot.docs;
          _totalAmountDue = total;
          _isLoading = false;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching unsettled orders: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isLoading = false; });
        showCustomSnackBar(context, 'حدث خطأ في Firebase أثناء جلب الطلبات غير المحاسب عليها: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error fetching unsettled orders: $e"); // إزالة الأقواس غير الضرورية
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isLoading = false; });
        showCustomSnackBar(context, 'تعذر جلب الطلبات غير المحاسب عليها.', isError: true);
      }
    }
  }

  Future<void> _requestSettlement() async {
    if (_totalAmountDue <= 0 || _unsettledOrders.isEmpty) {
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'لا توجد مستحقات لطلب التحاسب.', isError: true);
      }
      return;
    }
    if (_isRequestingSettlement) return;

    setState(() { _isRequestingSettlement = true; });

    try {
      DocumentSnapshot merchantDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      String merchantName = merchantDoc['name'] ?? merchantDoc['storeName'] ?? 'تاجر غير معروف';

      await _firestore.collection('settlements').add({
        'userId': _currentUser!.uid,
        'userType': 'merchant',
        'date': FieldValue.serverTimestamp(),
        'orderIds': _unsettledOrders.map((doc) => doc.id).toList(),
        'totalAmount': _totalAmountDue,
        'status': 'pending_admin_approval',
        'isApprovedByAdmin': false,
      });

      // افتراض أن دالة sendNotificationToAdmins مُعرّفة ومُتاحة (تم توفيرها في ملفات سابقة)
      await sendNotificationToAdmins(
        _firestore,
        'طلب تحاسب جديد من تاجر',
        // إزالة الأقواس غير الضرورية
        'التاجر $merchantName (ID: ${_currentUser!.uid}) طلب تحاسب بمبلغ ${_totalAmountDue.toStringAsFixed(0)} دينار. يرجى المراجعة والموافقة.',
        type: 'settlement_request',
        senderId: _currentUser!.uid,
        senderName: merchantName,
      );

      if (mounted) {
        showCustomSnackBar(context, 'تم إرسال طلب التحاسب بنجاح. يرجى انتظار موافقة الإدارة.', isSuccess: true);
        _fetchUnsettledOrders();
      }

    } on FirebaseException catch (e) {
      debugPrint("Firebase Error requesting settlement: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ في Firebase عند طلب التحاسب: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error requesting settlement: $e"); // إزالة الأقواس غير الضرورية
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ غير متوقع عند طلب التحاسب.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() { _isRequestingSettlement = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // لتحديد اتجاه النص

    if (_currentUser == null) {
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
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: colorScheme.onSurface),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MerchantSettlementHistoryScreen()));
            },
            tooltip: 'سجل التحاسب',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16.0),
            elevation: cardTheme.elevation,
            shape: cardTheme.shape,
            color: cardTheme.color,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // استخدام isRtl
                children: [
                  Text(
                    "المستحقات الحالية",
                    style: textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    'إجمالي المبلغ المستحق: ${_totalAmountDue.toStringAsFixed(0)} دينار',
                    style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                    textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                  ),
                  const SizedBox(height: 20.0),
                  _isRequestingSettlement
                      ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                      : ElevatedButton(
                    onPressed: _requestSettlement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    child: Text('طلب التحاسب', style: textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _unsettledOrders.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_turned_in_outlined, size: 80, color: Color.fromRGBO(189, 189, 189, 1)),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد طلبات مكتملة غير محاسب عليها حالياً.',
                    style: textTheme.titleMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: _unsettledOrders.length,
              itemBuilder: (context, index) {
                DocumentSnapshot order = _unsettledOrders[index];
                double orderNetPrice = ((order['totalPrice'] as num?) ?? 0.0).toDouble() - ((order['companyShare'] as num?)?.toDouble() ?? 0.0);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  elevation: cardTheme.elevation,
                  shape: cardTheme.shape,
                  color: cardTheme.color,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    title: Text(
                      'طلب رقم: #${order['orderNumber'] ?? order.id}',
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                    ),
                    subtitle: Text(
                      'العميل: ${order['customerName'] ?? 'غير معروف'} | التاريخ: ${DateFormat('yyyy-MM-dd').format((order['createdAt'] as Timestamp).toDate())}',
                      style: textTheme.bodySmall?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                    ),
                    trailing: Text(
                      'لك: ${orderNetPrice.toStringAsFixed(0)} د.ع',
                      style: textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                      textDirection: TextDirection.ltr, // يفضل LTR للأرقام
                    ),
                    onTap: () {
                      if (mounted) { // التحقق من mounted
                        showCustomSnackBar(context, "تفاصيل الطلب: ${order['orderNumber'] ?? order.id}", isSuccess: true);
                      }
                    },
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