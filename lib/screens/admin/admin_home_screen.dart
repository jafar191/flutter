import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';

import '../../common/notifications_screen.dart';
import '../../common/search_screen.dart';
import '../../common/support_chat_screen.dart';
import '../auth/login_screen.dart';

import 'admin_order_management_screen.dart';
import 'admin_user_management_screen.dart';
import 'admin_financial_settlement_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_ads_notifications_screen.dart';
import 'admin_activity_log_screen.dart';


class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  bool _isRefreshing = false;
  int _refreshTimer = 10;
  Timer? _timer;

  int _totalOrders = 0;
  int _completedOrders = 0;
  double _expectedCompanyRevenue = 0.0;
  int _activeUsers = 0;
  int _reportedOrders = 0;
  String _adminName = 'المسؤول';

  List<PieChartSectionData> _orderStatusSections = [];
  List<FlSpot> _revenueSpots = [];

  int _selectedIndex = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;

    await _fetchAdminProfile();
    await _fetchKpis();
    await _fetchChartData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAdminProfile() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          _adminName = userDoc['name'] ?? 'المسؤول';
        });
      }
    } catch (e) {
      debugPrint("Error fetching admin profile: $e");
    }
  }

  Future<void> _fetchKpis() async {
    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .get();
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final totalOrders = ordersSnapshot.docs.length;
      final completedOrders = ordersSnapshot.docs
          .where((doc) => doc['status'] == 'delivered')
          .length;
      // تأكد من أن حصة الشركة (500.0) يتم جلبها ديناميكيًا إذا كانت متغيرة
      final expectedRevenue = completedOrders * 500.0;
      final activeUsers = usersSnapshot.docs
          .where((doc) => doc['status'] == 'active')
          .length;
      final reportedOrders = ordersSnapshot.docs
          .where((doc) => doc['status'] == 'reported')
          .length;

      if (mounted) {
        setState(() {
          _totalOrders = totalOrders;
          _completedOrders = completedOrders;
          _expectedCompanyRevenue = expectedRevenue;
          _activeUsers = activeUsers;
          _reportedOrders = reportedOrders;
        });
      }
    } catch (e) {
      debugPrint("Error fetching KPIs: $e");
    }
  }

  Future<void> _fetchChartData() async {
    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .get();
      final Map<String, int> statusCounts = {};

      for (final doc in ordersSnapshot.docs) {
        final String status = doc['status'] as String? ?? 'unknown';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      final List<PieChartSectionData> sections = [];
      statusCounts.forEach((status, statusCount) { // تم تغيير اسم المتغير count إلى statusCount
        Color color;
        switch (status) {
          case 'pending':
            color = Colors.blue;
            break;
          case 'in_progress':
            color = Colors.orange;
            break;
          case 'delivered':
            color = Colors.green;
            break;
          case 'reported':
            color = Colors.red;
            break;
          case 'return_requested':
            color = Colors.purple;
            break;
          case 'return_completed':
            color = Colors.teal;
            break;
          case 'cancelled':
            color = Colors.grey;
            break;
          default:
            color = Colors.grey;
        }
        sections.add(
          PieChartSectionData(
            color: color,
            value: statusCount.toDouble(),
            title: '$statusCount',
            radius: 40,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Cairo',
            ),
          ),
        );
      });

      // هذه البيانات تبدو ثابتة، يمكنك جلبها ديناميكيًا إذا لزم الأمر
      const List<FlSpot> revenueSpots = [
        FlSpot(0, 3),
        FlSpot(1, 5),
        FlSpot(2, 4),
        FlSpot(3, 7),
        FlSpot(4, 6),
      ];

      if (mounted) {
        setState(() {
          _orderStatusSections = sections;
          _revenueSpots = revenueSpots;
        });
      }
    } catch (e) {
      debugPrint("Error fetching chart data: $e");
    }
  }

  void _startRefresh() {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _refreshTimer = 10;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_refreshTimer == 0) {
        _timer?.cancel();
        if (mounted) {
          setState(() {
            _isRefreshing = false;
            _fetchInitialData();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _refreshTimer--;
          });
        }
      }
    });
  }

  void _openDrawer() {
    if (mounted) {
      _scaffoldKey.currentState?.openDrawer();
    }
  }

  void _showAdminQuickActions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('تحميل صورة إعلان', style: TextStyle(fontFamily: 'Cairo')),
                onTap: () {
                  Navigator.pop(bc);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAdsNotificationsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.send),
                title: const Text('إرسال إشعار', style: TextStyle(fontFamily: 'Cairo')),
                onTap: () {
                  Navigator.pop(bc);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAdsNotificationsScreen(initialTab: 1,)));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _onKpiCardTap(String category) {
    String? statusFilter;
    bool isUserManagement = false;

    switch (category) {
      case 'إجمالي الطلبات':
        statusFilter = 'all';
        break;
      case 'طلبات مكتملة':
        statusFilter = 'delivered';
        break;
      case 'مستخدمون نشطون':
        isUserManagement = true;
        break;
      case 'طلبات مبلغة':
        statusFilter = 'reported';
        break;
      case 'إيرادات متوقعة':
        // The name 'AdminReportsScreen' isn't a class.
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminReportsScreen()));
        return;
      case 'كل الطلبات':
        statusFilter = 'all';
        break;
      case 'طلبات قيد الانتظار':
        statusFilter = 'pending';
        break;
      case 'قيد التسليم':
        statusFilter = 'in_progress';
        break;
      case 'تم التسليم':
        statusFilter = 'delivered';
        break;
      case 'ملغاة':
        statusFilter = 'cancelled';
        break;
      case 'مرتجعة':
        statusFilter = 'return_requested'; // في حالتك، كانت 'returned' في orderCategories
        break;
    }

    if (isUserManagement) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminUserManagementScreen(),
        ),
      );
    } else if (statusFilter != null) { // تأكد من أن statusFilter ليس null قبل استخدامه
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminOrderManagementScreen(initialFilterStatus: statusFilter),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme; // تم استخدامها الآن

    // المتغير isRtl لتحديد اتجاه النص
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;


    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("لوحة التحكم", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
        centerTitle: true,
        // The argument for the named parameter 'drawer' was already specified.
        // تم إزالة `leading` المكرر الذي يفتح الدرج
        // leading: Builder(
        //   builder: (BuildContext context) {
        //     return IconButton(
        //       icon: const Icon(Icons.menu),
        //       color: colorScheme.onSurface,
        //       onPressed: () {
        //         Scaffold.of(context).openDrawer();
        //       },
        //     );
        //   },
        // ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? Text('$_refreshTimer s',
                style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface))
                : Icon(Icons.refresh, color: colorScheme.onSurface),
            onPressed: _startRefresh,
          ),
          IconButton(
            icon: Icon(Icons.logout, color: colorScheme.onSurface),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),
      drawer: _buildSidebar(isRtl), // تم تمرير isRtl إلى Sidebar
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 1.5,
              ),
              itemCount: 5,
              itemBuilder: (context, index) {
                String title;
                String value;
                Color color;
                IconData icon;

                switch (index) {
                  case 0:
                    title = 'إجمالي الطلبات';
                    value = _totalOrders.toString();
                    color = colorScheme.primary;
                    icon = Icons.receipt_long;
                    break;
                  case 1:
                    title = 'طلبات مكتملة';
                    color = Colors.green;
                    icon = Icons.check_circle_outline;
                    value = _completedOrders.toString();
                    break;
                  case 2:
                    title = 'إيرادات متوقعة';
                    value = '${_expectedCompanyRevenue.toInt()} د.ع';
                    color = colorScheme.secondary;
                    icon = Icons.attach_money;
                    break;
                  case 3:
                    title = 'مستخدمون نشطون';
                    value = _activeUsers.toString();
                    color = Colors.teal;
                    icon = Icons.people_outline;
                    break;
                  default: // Case 4
                    title = 'طلبات مبلغة';
                    value = _reportedOrders.toString();
                    color = Colors.red;
                    icon = Icons.warning_amber;
                }
                return _buildKpiCard(title, value, color, icon, () => _onKpiCardTap(title), isRtl); // تمرير isRtl
              },
            ),
            const SizedBox(height: 24.0),

            Text(
              "أقسام الطلبات",
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
            ),
            const SizedBox(height: 16.0),
            _buildOrderCategoriesSection(isRtl), // تمرير isRtl

            const SizedBox(height: 24.0),
            Text(
              "تحليلات الطلبات",
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
            ),
            const SizedBox(height: 16.0),
            _orderStatusSections.isEmpty
                ? Container(
              height: 200,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cardTheme.color,
                // The argument type 'BorderRadiusGeometry' can't be assigned to the parameter type 'BorderRadius?'.
                borderRadius: cardTheme.shape is RoundedRectangleBorder
                    ? (cardTheme.shape as RoundedRectangleBorder).borderRadius
                    : BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.1).round()), // withOpacity is deprecated
                    blurRadius: 5,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: CircularProgressIndicator(color: colorScheme.primary),
            )
                : Container(
              height: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardTheme.color,
                // The argument type 'BorderRadiusGeometry' can't be assigned to the parameter type 'BorderRadius?'.
                borderRadius: cardTheme.shape is RoundedRectangleBorder
                    ? (cardTheme.shape as RoundedRectangleBorder).borderRadius
                    : BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.1).round()), // withOpacity is deprecated
                    blurRadius: 5,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: PieChart(
                PieChartData(
                  sections: _orderStatusSections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  borderData: FlBorderData(show: false),
                  pieTouchData: PieTouchData(
                      touchCallback:
                          (FlTouchEvent event, pieTouchResponse) {}),
                ),
              ),
            ),
            const SizedBox(height: 24.0),
            Text(
              "اتجاهات الإيرادات",
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
            ),
            const SizedBox(height: 16.0),
            _revenueSpots.isEmpty
                ? Container(
              height: 200,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cardTheme.color,
                // The argument type 'BorderRadiusGeometry' can't be assigned to the parameter type 'BorderRadius?'.
                borderRadius: cardTheme.shape is RoundedRectangleBorder
                    ? (cardTheme.shape as RoundedRectangleBorder).borderRadius
                    : BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.1).round()), // withOpacity is deprecated
                    blurRadius: 5,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: CircularProgressIndicator(color: colorScheme.primary),
            )
                : Container(
              height: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardTheme.color,
                borderRadius: cardTheme.shape is RoundedRectangleBorder
                    ? (cardTheme.shape as RoundedRectangleBorder).borderRadius
                    : BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.1).round()), // withOpacity is deprecated
                    blurRadius: 5,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _revenueSpots,
                      isCurved: true,
                      color: colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true), // Use const
                      belowBarData: BarAreaData(
                          show: true,
                          color: colorScheme.primary.withAlpha((255 * 0.3).round())), // withOpacity is deprecated
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (!mounted) return;
          setState(() {
            _selectedIndex = index;
          });
          switch (index) {
            case 0:
            // Stay on home screen
              break;
            case 1:
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SearchScreen()));
              break;
            case 2:
              _showAdminQuickActions();
              break;
            case 3:
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NotificationsScreen()));
              break;
            case 4:
              _openDrawer();
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'البحث',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'إجراءات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'الإشعارات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu),
            label: 'المزيد',
          ),
        ],
      ),
      // تم حذف `drawer` المكرر
    );
  }

  Widget _buildKpiCard(String title, String value, Color color, IconData icon, VoidCallback onTap, bool isRtl) {
    final textTheme = Theme.of(context).textTheme;
    final cardTheme = Theme.of(context).cardTheme;

    return Card(
      elevation: cardTheme.elevation,
      shape: cardTheme.shape,
      color: cardTheme.color,
      child: InkWell(
        onTap: onTap,
        borderRadius: cardTheme.shape is RoundedRectangleBorder
            ? (cardTheme.shape as RoundedRectangleBorder).borderRadius
            : BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // استخدام isRtl
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(
                alignment: isRtl ? Alignment.topRight : Alignment.topLeft, // استخدام isRtl
                child: Row(
                  mainAxisAlignment: isRtl ? MainAxisAlignment.end : MainAxisAlignment.start, // استخدام isRtl
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, color: color, size: 28),
                  ],
                ),
              ),
              const Spacer(),
              Align(
                alignment: isRtl ? Alignment.bottomRight : Alignment.bottomLeft, // استخدام isRtl
                child: Text(
                  value,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCategoriesSection(bool isRtl) { // إضافة isRtl كمعلمة
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // final cardTheme = Theme.of(context).cardTheme; // هذا المتغير غير مستخدم هنا

    final List<Map<String, dynamic>> orderCategories = [
      {'title': 'كل الطلبات', 'status': 'all', 'icon': Icons.list_alt, 'color': colorScheme.primary},
      {'title': 'طلبات قيد الانتظار', 'status': 'pending', 'icon': Icons.hourglass_empty, 'color': Colors.orange},
      {'title': 'قيد التسليم', 'status': 'in_progress', 'icon': Icons.delivery_dining, 'color': Colors.lightGreen},
      {'title': 'تم التسليم', 'status': 'delivered', 'icon': Icons.check_circle_outline, 'color': Colors.green},
      {'title': 'ملغاة', 'status': 'cancelled', 'icon': Icons.cancel_outlined, 'color': Colors.grey},
      {'title': 'مرتجعة', 'status': 'return_requested', 'icon': Icons.assignment_return, 'color': Colors.purple}, // تم تصحيح الحالة هنا
    ];

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: orderCategories.length + 1,
        itemBuilder: (context, index) {
          if (index == orderCategories.length) {
            return _buildViewMoreCategoryCard(isRtl); // تمرير isRtl
          }

          final category = orderCategories[index];
          return _buildCategoryCard(
            category['title'] as String,
            category['icon'] as IconData,
            category['color'] as Color,
            () => _onKpiCardTap(category['title'] as String),
            isRtl, // تمرير isRtl
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color, VoidCallback onTap, bool isRtl) { // إضافة isRtl
    final textTheme = Theme.of(context).textTheme;
    final cardTheme = Theme.of(context).cardTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: cardTheme.elevation,
      shape: cardTheme.shape,
      color: cardTheme.color,
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: cardTheme.shape is RoundedRectangleBorder
            ? (cardTheme.shape as RoundedRectangleBorder).borderRadius
            : BorderRadius.circular(12.0),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewMoreCategoryCard(bool isRtl) { // إضافة isRtl
    final textTheme = Theme.of(context).textTheme;
    final cardTheme = Theme.of(context).cardTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: cardTheme.elevation,
      shape: cardTheme.shape,
      color: cardTheme.color,
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminOrderManagementScreen(initialFilterStatus: null),
            ),
          );
        },
        borderRadius: cardTheme.shape is RoundedRectangleBorder
            ? (cardTheme.shape as RoundedRectangleBorder).borderRadius
            : BorderRadius.circular(12.0),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_forward_ios, size: 36, color: colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                'عرض المزيد',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(bool isRtl) { // إضافة isRtl
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // استخدام isRtl
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Align(
                  alignment: isRtl ? Alignment.topRight : Alignment.topLeft, // استخدام isRtl
                  child: IconButton(
                    icon: const Icon(Icons.brightness_2, color: Colors.white),
                    onPressed: () {
                      debugPrint("تبديل الوضع الليلي");
                    },
                  ),
                ),
                const SizedBox(height: 8.0),

                Text(
                  "مرحباً أيها المسؤول",
                  style: textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                ),
                const SizedBox(height: 4.0),
                Text(
                  _adminName,
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: Text('لوحة التحكم',
                textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                style: textTheme.bodyMedium),
            onTap: () {
              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: Text('إدارة الطلبات',
                textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                style: textTheme.bodyMedium),
            onTap: () {
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                      const AdminOrderManagementScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: Text('إدارة المستخدمين',
                textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                style: textTheme.bodyMedium),
            onTap: () {
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                      const AdminUserManagementScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: Text('التحاسب المالي',
                textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                style: textTheme.bodyMedium),
            onTap: () {
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                      const AdminFinancialSettlementScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: Text('التقارير والتحليلات',
                textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                style: textTheme.bodyMedium),
            onTap: () {
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminReportsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.campaign),
            title: Text('إدارة الإعلانات والإشعارات',
                textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                style: textTheme.bodyMedium),
            onTap: () {
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                      const AdminAdsNotificationsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text('سجل الإجراءات الإدارية',
                textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                style: textTheme.bodyMedium),
            onTap: () {
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminActivityLogScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: Text('الدعم الفني',
                textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                style: textTheme.bodyMedium),
            onTap: () {
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                      const SupportChatScreen(targetUserId: null, targetUserName: null)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text('تسجيل الخروج',
                textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                style: textTheme.bodyMedium),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}