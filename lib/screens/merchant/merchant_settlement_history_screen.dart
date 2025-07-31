import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';


class MerchantSettlementHistoryScreen extends StatefulWidget {
  const MerchantSettlementHistoryScreen({super.key});

  @override
  State<MerchantSettlementHistoryScreen> createState() => _MerchantSettlementHistoryScreenState();
}

class _MerchantSettlementHistoryScreenState extends State<MerchantSettlementHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
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
          title: Text("سجل التحاسب", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("سجل التحاسب", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('settlements')
            .where('userId', isEqualTo: _currentUser!.uid)
            .where('userType', isEqualTo: 'merchant')
            .where('status', isEqualTo: 'paid')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: colorScheme.primary));
          }
          if (snapshot.hasError) {
            debugPrint("Settlement History Stream Error: ${snapshot.error}");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'حدث خطأ في جلب سجلات التحاسب: ${snapshot.error}',
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
                  const Icon(Icons.history_toggle_off, size: 80, color: Color.fromRGBO(189, 189, 189, 1)),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد سجلات تحاسب حالياً.',
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
              DocumentSnapshot settlement = snapshot.data!.docs[index];
              DateTime settlementDate = (settlement['date'] as Timestamp).toDate();
              double totalAmount = (settlement['totalAmount'] as num?)?.toDouble() ?? 0.0;
              String settlementStatus = settlement['status'] as String? ?? 'unknown';

              Color statusColor = Colors.grey;
              if (settlementStatus == 'paid') {
                statusColor = colorScheme.primary;
              } else if (settlementStatus == 'approved') {
                statusColor = Colors.blue;
              } else if (settlementStatus == 'pending_admin_approval') {
                statusColor = colorScheme.secondary;
              } else if (settlementStatus == 'rejected') {
                statusColor = colorScheme.error;
              }


              return Card(
                elevation: cardTheme.elevation,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: cardTheme.shape,
                color: cardTheme.color,
                child: ExpansionTile(
                  collapsedBackgroundColor: cardTheme.color,
                  backgroundColor: cardTheme.color,
                  shape: cardTheme.shape,
                  collapsedShape: cardTheme.shape,
                  title: Text(
                    'فاتورة تاريخ: ${DateFormat('yyyy-MM-dd').format(settlementDate)}',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                    textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                  ),
                  subtitle: Text(
                    'إجمالي المبلغ المستلم: ${totalAmount.toStringAsFixed(0)} دينار | الحالة: ${_translateSettlementStatus(settlementStatus)}',
                    style: textTheme.bodyMedium?.copyWith(color: statusColor),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                    textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                  ),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  children: [
                    Column(
                      crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // استخدام isRtl
                      children: [
                        Text('الطلبات المشمولة:',
                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                        ),
                        const SizedBox(height: 8.0),
                        if (settlement['orderIds'] != null && (settlement['orderIds'] as List).isNotEmpty)
                        // تم إزالة toList() غير الضرورية
                          ...(settlement['orderIds'] as List<dynamic>).map((orderId) =>
                              Text(
                                '#$orderId',
                                style: textTheme.bodySmall,
                                textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                              ),
                          )
                        else
                          Text(
                            'لا توجد طلبات مرتبطة بهذا التحاسب.',
                            style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                          ),
                        const SizedBox(height: 8.0),
                        if (settlement['approvedByAdminId'] != null)
                          Text('تمت الموافقة بواسطة: ${settlement['approvedByAdminName'] ?? 'الإدارة'}',
                            style: textTheme.bodySmall?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                          ),
                        if (settlement['paidByAdminId'] != null)
                          Text('تم الدفع بواسطة: ${settlement['paidByAdminName'] ?? 'الإدارة'}',
                            style: textTheme.bodySmall?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                          ),
                        Text(
                          'تاريخ الإجراء: ${DateFormat('yyyy-MM-dd HH:mm').format(settlementDate)}',
                          style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // يفضل LTR للتاريخ/الوقت
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _translateSettlementStatus(String status) {
    switch (status) {
      case 'pending_admin_approval': return 'بانتظار موافقة الإدارة';
      case 'approved': return 'تمت الموافقة';
      case 'paid': return 'تم الدفع';
      case 'rejected': return 'مرفوض';
      default: return status;
    }
  }
}