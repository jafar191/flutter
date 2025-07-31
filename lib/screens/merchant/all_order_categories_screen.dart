import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

import 'order_list_screen.dart';
// هذا الاستيراد يبدو غير مستخدم بشكل مباشر هنا
// import '../admin/admin_user_profile_screen.dart';
// افتراض وجود showCustomSnackBar في common/custom_snackbar.dart
import '../../common/custom_snackbar.dart';


class AllOrderCategoriesScreen extends StatefulWidget {
  const AllOrderCategoriesScreen({super.key});

  @override
  State<AllOrderCategoriesScreen> createState() => _AllOrderCategoriesScreenState();
}

class _AllOrderCategoriesScreenState extends State<AllOrderCategoriesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, int> _orderCounts = {};
  int _totalOrders = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrderCounts();
  }

  Future<void> _fetchOrderCounts() async {
    if (!mounted) return;

    User? user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      QuerySnapshot ordersSnapshot = await _firestore
          .collection('orders')
          .where('merchantId', isEqualTo: user.uid)
          .get();

      Map<String, int> counts = {
        'all': 0,
        'pending': 0,
        'in_progress': 0,
        'reported': 0,
        'delivered': 0,
        'return_requested': 0,
        'return_completed': 0,
        'cancelled': 0,
      };

      for (var doc in ordersSnapshot.docs) {
        String status = doc['status'] as String? ?? 'unknown';

        counts['all'] = (counts['all'] ?? 0) + 1;

        if (counts.containsKey(status)) {
          counts[status] = (counts[status] ?? 0) + 1;
        } else {
          counts[status] = (counts[status] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _orderCounts = counts;
          _totalOrders = counts['all'] ?? 0;
          _isLoading = false;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching all order counts: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() => _isLoading = false);
        showCustomSnackBar(context, 'حدث خطأ في Firebase أثناء جلب إحصائيات الطلبات: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error fetching all order counts: $e"); // إزالة الأقواس غير الضرورية
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() => _isLoading = false);
        showCustomSnackBar(context, 'تعذر جلب إحصائيات الطلبات.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme; // تم استخدامها الآن

    final List<Map<String, dynamic>> orderCategories = [
      {'title': 'جميع الطلبات', 'status': 'all', 'color': colorScheme.primary, 'icon': Icons.list_alt},
      {'title': 'مسجلة', 'status': 'pending', 'color': Colors.blue, 'icon': Icons.pending_actions},
      {'title': 'قيد التوصيل', 'status': 'in_progress', 'color': Colors.orange, 'icon': Icons.delivery_dining},
      {'title': 'مشاكل', 'status': 'reported', 'color': colorScheme.error, 'icon': Icons.warning_amber},
      {'title': 'مكتملة', 'status': 'delivered', 'color': Colors.green, 'icon': Icons.check_circle_outline},
      {'title': 'مرتجعة', 'status': 'return_requested', 'color': Colors.purple, 'icon': Icons.assignment_return},
      {'title': 'تم الإرجاع', 'status': 'return_completed', 'color': Colors.teal, 'icon': Icons.assignment_returned},
      {'title': 'ملغاة', 'status': 'cancelled', 'color': Colors.grey, 'icon': Icons.cancel_outlined},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("جميع أقسام الطلبات", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 1.2,
        ),
        itemCount: orderCategories.length,
        itemBuilder: (context, index) {
          final category = orderCategories[index];
          String title = category['title'] as String;
          String statusKey = category['status'] as String;
          Color color = category['color'] as Color;
          IconData icon = category['icon'] as IconData;
          int count = _orderCounts[statusKey] ?? 0;

          return _buildCategoryCard(context, title, statusKey, count, color, icon);
        },
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title, String statusKey, int count, Color color, IconData icon) {
    final textTheme = Theme.of(context).textTheme;
    final cardTheme = Theme.of(context).cardTheme;
    final colorScheme = Theme.of(context).colorScheme;

    double remainingValue = (_totalOrders - count).toDouble();
    if (remainingValue < 0) remainingValue = 0;

    return Card(
      elevation: cardTheme.elevation,
      shape: cardTheme.shape,
      color: cardTheme.color,
      child: InkWell(
        // The argument type 'BorderRadiusGeometry' can't be assigned to the parameter type 'BorderRadius?'.
        borderRadius: cardTheme.shape is RoundedRectangleBorder
            ? (cardTheme.shape as RoundedRectangleBorder).borderRadius
            : BorderRadius.circular(12.0),
        onTap: () {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderListScreen(
                status: statusKey,
                title: title,
                userId: FirebaseAuth.instance.currentUser!.uid,
                userType: 'merchant',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 10.0),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10.0),
              SizedBox(
                width: 80,
                height: 80,
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        color: color,
                        value: count.toDouble(),
                        title: '$count',
                        radius: 35,
                        titleStyle: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: color.withAlpha(76),
                        value: remainingValue,
                        title: '',
                        radius: 35,
                      ),
                    ],
                    sectionsSpace: 0,
                    centerSpaceRadius: 30,
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}