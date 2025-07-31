import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'admin_user_profile_screen.dart';
import 'admin_settlement_history_screen.dart';
import '../../common/custom_snackbar.dart'; // افتراض وجود showCustomSnackBar


class AdminFinancialSettlementScreen extends StatefulWidget {
  const AdminFinancialSettlementScreen({super.key});

  @override
  State<AdminFinancialSettlementScreen> createState() => _AdminFinancialSettlementScreenState();
}

class _AdminFinancialSettlementScreenState extends State<AdminFinancialSettlementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, String> _userNames = {};
  final Map<String, bool> _isProcessingSettlement = {};


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUserNames();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserNames() async {
    try {
      QuerySnapshot usersSnapshot = await _firestore.collection('users').get();
      Map<String, String> names = {};
      for (var doc in usersSnapshot.docs) {
        names[doc.id] = doc['name'] ?? doc['storeName'] ?? 'غير معروف';
      }
      if (mounted) {
        setState(() {
          _userNames = names;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user names for history: $e"); // إزالة الأقواس
      if (mounted) {
        showCustomSnackBar(context, 'حدث خطأ عند جلب أسماء المستخدمين.', isError: true);
      }
    }
  }

  Future<void> _approveDriverSettlement(DocumentSnapshot settlementDoc) async {
    if (!mounted) return;
    if (_isProcessingSettlement[settlementDoc.id] == true) return;

    setState(() {
      _isProcessingSettlement[settlementDoc.id] = true;
    });

    try {
      final String? adminId = _auth.currentUser?.uid;
      if (adminId == null) {
        if (mounted) { // التحقق من mounted قبل استخدام context
          showCustomSnackBar(context, 'خطأ: غير مصرح لك بتنفيذ هذا الإجراء.', isError: true);
        }
        return;
      }

      await _firestore.collection('settlements').doc(settlementDoc.id).update({
        'status': 'approved',
        'isApprovedByAdmin': true,
        'approvedByAdminId': adminId,
        'approvalDate': FieldValue.serverTimestamp(),
      });

      List<dynamic> orderIds = settlementDoc['orderIds'] ?? [];
      WriteBatch batch = _firestore.batch();
      for (String orderId in orderIds) {
        batch.update(_firestore.collection('orders').doc(orderId), {'isSettledDriver': true});
      }
      await batch.commit();

      await _firestore.collection('notifications').add({
        'userId': settlementDoc['userId'],
        'title': 'تمت الموافقة على تحاسبك!',
        // إزالة الأقواس غير الضرورية
        'body': 'لقد تمت الموافقة على تحاسبك بتاريخ ${DateFormat('yyyy-MM-dd').format((settlementDoc['date'] as Timestamp).toDate())}.',
        'type': 'settlement_approved',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showCustomSnackBar(context, 'تمت الموافقة على تحاسب المندوب بنجاح!', isSuccess: true);
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error approving driver settlement: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ في Firebase عند الموافقة على التحاسب: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("General Error approving driver settlement: $e"); // إزالة الأقواس
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ غير متوقع عند الموافقة على التحاسب.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingSettlement.remove(settlementDoc.id);
        });
      }
    }
  }

  Future<void> _payMerchantSettlement(DocumentSnapshot settlementDoc) async {
    if (!mounted) return;
    if (_isProcessingSettlement[settlementDoc.id] == true) return;

    setState(() {
      _isProcessingSettlement[settlementDoc.id] = true;
    });

    try {
      final String? adminId = _auth.currentUser?.uid;
      if (adminId == null) {
        if (mounted) { // التحقق من mounted قبل استخدام context
          showCustomSnackBar(context, 'خطأ: غير مصرح لك بتنفيذ هذا الإجراء.', isError: true);
        }
        return;
      }

      await _firestore.collection('settlements').doc(settlementDoc.id).update({
        'status': 'paid',
        'isPaidToMerchant': true,
        'paidByAdminId': adminId,
        'paymentDate': FieldValue.serverTimestamp(),
      });

      List<dynamic> orderIds = settlementDoc['orderIds'] ?? [];
      WriteBatch batch = _firestore.batch();
      for (String orderId in orderIds) {
        batch.update(_firestore.collection('orders').doc(orderId), {'isSettledMerchant': true});
      }
      await batch.commit();

      await _firestore.collection('notifications').add({
        'userId': settlementDoc['userId'],
        'title': 'تم دفع مستحقاتك!',
        // إزالة الأقواس غير الضرورية
        'body': 'لقد تم دفع مستحقات طلباتك بتاريخ ${DateFormat('yyyy-MM-dd').format((settlementDoc['date'] as Timestamp).toDate())} بمبلغ ${settlementDoc['totalAmount']?.toStringAsFixed(0) ?? '0'} دينار.',
        'type': 'settlement_paid',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showCustomSnackBar(context, 'تم دفع مستحقات التاجر بنجاح!', isSuccess: true);
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error paying merchant settlement: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ في Firebase عند دفع المستحقات: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("General Error paying merchant settlement: $e"); // إزالة الأقواس
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ غير متوقع عند دفع المستحقات.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingSettlement.remove(settlementDoc.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // لتحديد اتجاه النص

    return Scaffold(
      appBar: AppBar(
        title: Text("التحاسب المالي", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: const Color.fromRGBO(117, 117, 117, 1),
          labelStyle: textTheme.labelLarge,
          unselectedLabelStyle: textTheme.labelMedium,
          tabs: const [ // استخدام const
            Tab(text: "تحاسب المندوبين", icon: Icon(Icons.delivery_dining)),
            Tab(text: "تحاسب التجار", icon: Icon(Icons.store)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft, // استخدام isRtl
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminSettlementHistoryScreen()),
                  );
                },
                icon: Icon(Icons.history, color: colorScheme.primary),
                label: Text('سجل التحاسب العام', style: textTheme.labelLarge?.copyWith(color: colorScheme.primary)),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSettlementList('driver', isRtl), // تمرير isRtl
                _buildSettlementList('merchant', isRtl), // تمرير isRtl
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementList(String userType, bool isRtl) { // إضافة isRtl
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('settlements')
          .where('userType', isEqualTo: userType)
          .where('status', isEqualTo: 'pending_admin_approval')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: colorScheme.primary));
        }
        if (snapshot.hasError) {
          debugPrint("Settlement List Stream Error: ${snapshot.error}");
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'حدث خطأ: ${snapshot.error}',
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
                const Icon(Icons.money_off, size: 80, color: Color.fromRGBO(189, 189, 189, 1)), // استخدام const
                const SizedBox(height: 16),
                Text(
                  'لا توجد طلبات تحاسب ${userType == 'driver' ? 'للمندوبين' : 'للتجار'} بانتظار الموافقة.',
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
            DocumentSnapshot settlementDoc = snapshot.data!.docs[index];
            String userId = settlementDoc['userId'] as String;
            String userName = _userNames[userId] ?? 'مستخدم غير معروف';
            DateTime settlementDate = (settlementDoc['date'] as Timestamp).toDate();
            double amount = (settlementDoc['totalAmount'] as num?)?.toDouble() ?? 0.0;

            final bool isProcessing = _isProcessingSettlement[settlementDoc.id] == true;

            return Card(
              elevation: cardTheme.elevation,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: cardTheme.shape,
              color: cardTheme.color,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                leading: Icon(
                  userType == 'driver' ? Icons.delivery_dining : Icons.store,
                  color: colorScheme.primary,
                  size: 30,
                ),
                title: Text(
                  '${userType == 'driver' ? 'المندوب' : 'التاجر'}: $userName',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                ),
                subtitle: Text(
                  'المبلغ: ${amount.toStringAsFixed(0)} دينار | التاريخ: ${DateFormat('yyyy-MM-dd').format(settlementDate)}',
                  style: textTheme.bodySmall?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                ),
                trailing: isProcessing
                    ? CircularProgressIndicator(color: colorScheme.primary)
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        if (userType == 'driver') {
                          _approveDriverSettlement(settlementDoc);
                        } else {
                          _payMerchantSettlement(settlementDoc);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: userType == 'driver' ? colorScheme.primary : colorScheme.secondary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text(
                        userType == 'driver' ? 'موافقة' : 'دفع',
                        style: textTheme.labelLarge?.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.person, color: Color.fromRGBO(117, 117, 117, 1)), // استخدام const
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => AdminUserProfileScreen(userId: userId)));
                      },
                      tooltip: 'عرض ملف المستخدم',
                    ),
                  ],
                ),
                onTap: () {
                  if (mounted) { // التحقق من mounted
                    showCustomSnackBar(context, 'تم النقر على تحاسب المستخدم: $userName', isSuccess: true);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}