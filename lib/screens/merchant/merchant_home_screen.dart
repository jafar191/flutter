import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../common/notifications_screen.dart';
import '../../common/search_screen.dart';
import '../../common/support_chat_screen.dart';
import '../auth/login_screen.dart';
import 'add_new_order_screen.dart';
import 'merchant_settlement_screen.dart';
import 'merchant_profile_screen.dart';
import 'merchant_reports_screen.dart';
import 'all_order_categories_screen.dart';
import 'order_list_screen.dart';
// هذا الاستيراد يبدو غير مستخدم بشكل مباشر هنا في MerchantHomeScreen
// import '../admin/admin_user_profile_screen.dart';
import '../../common/custom_snackbar.dart'; // افتراض وجود showCustomSnackBar


class MerchantHomeScreen extends StatefulWidget {
  const MerchantHomeScreen({super.key});

  @override
  State<MerchantHomeScreen> createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen> {
  bool _isRefreshing = false;
  int _refreshTimer = 10;
  Timer? _timer;

  final PageController _pageController = PageController();
  List<String> _adImages = [];

  int _problemsCount = 0;
  int _completedCount = 0;
  int _returnedCount = 0;
  String _merchantName = 'التاجر';

  final Map<String, dynamic> _quickStats = {
    'إجمالي الطلبات هذا الشهر': 0,
    'الربح المتوقع هذا الأسبوع': 0,
    'الطلبات المعلقة اليوم': 0,
  };

  int _selectedIndex = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;

    await _fetchMerchantProfile();

    await _fetchAdImages();
    await _fetchOrderStatistics();
    await _fetchQuickStats();

    if (mounted && _adImages.isNotEmpty && _adImages.length > 1) {
      _startAdAutoScroll();
    }
  }

  void _startAdAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_pageController.page!.toInt() + 1) % _adImages.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeIn,
        );
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchAdImages() async {
    try {
      QuerySnapshot adsSnapshot = await FirebaseFirestore.instance
          .collection('ads')
          .where('isActive', isEqualTo: true)
          .orderBy('order', descending: false)
          .get();

      if (mounted) {
        setState(() {
          _adImages = adsSnapshot.docs.map((doc) => doc['imageUrl'] as String).toList();
          if (_adImages.isEmpty) {
            _adImages = ['https://via.placeholder.com/600x250/cccccc/808080?text=لا توجد إعلانات حالياً'];
          }
        });
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching ads: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ في Firebase أثناء جلب الإعلانات: ${e.message}', isError: true);
        setState(() {
          _adImages = ['https://via.placeholder.com/600x250/cccccc/808080?text=فشل تحميل الإعلانات'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching ads: $e"); // إزالة الأقواس غير الضرورية
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'تعذر جلب الإعلانات.', isError: true);
        setState(() {
          _adImages = ['https://via.placeholder.com/600x250/cccccc/808080?text=فشل تحميل الإعلانات'];
        });
      }
    }
  }

  Future<void> _fetchOrderStatistics() async {
    try {
      String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      QuerySnapshot ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('merchantId', isEqualTo: currentUserId)
          .get();

      int problems = 0;
      int completed = 0;
      int returned = 0;

      for (var doc in ordersSnapshot.docs) {
        String status = doc['status'] as String? ?? 'unknown';

        if (status == 'reported') {
          problems++;
        } else if (status == 'delivered') {
          completed++;
        }
        if (status == 'return_requested' || status == 'return_completed') {
          returned++;
        }
      }

      if (mounted) {
        setState(() {
          _problemsCount = problems;
          _completedCount = completed;
          _returnedCount = returned;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching order statistics: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ في Firebase أثناء جلب إحصائيات الطلبات: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error fetching order statistics: $e"); // إزالة الأقواس غير الضرورية
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'تعذر جلب إحصائيات الطلبات.', isError: true);
      }
    }
  }

  Future<void> _fetchMerchantProfile() async {
    try {
      String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _merchantName = userDoc['name'] ?? userDoc['storeName'] ?? 'التاجر';
        });
      }
    } catch (e) {
      debugPrint("Error fetching merchant profile: $e"); // إزالة الأقواس غير الضرورية
    }
  }

  Future<void> _fetchQuickStats() async {
    try {
      String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      DateTime startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      DateTime now = DateTime.now();
      DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));

      QuerySnapshot allOrdersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('merchantId', isEqualTo: currentUserId)
          .get();

      int totalOrdersThisMonth = 0;
      int pendingOrdersToday = 0;
      double estimatedWeeklyProfit = 0.0;

      for (var doc in allOrdersSnapshot.docs) {
        final String status = doc['status'] as String? ?? 'unknown';
        final Timestamp createdAtTimestamp = doc['createdAt'] as Timestamp;
        final DateTime createdAtDate = createdAtTimestamp.toDate();
        final double totalPrice = (doc['totalPrice'] as num?)?.toDouble() ?? 0.0;
        // final double _ = (doc['deliveryCost'] as num?)?.toDouble() ?? 0.0; // هذا المتغير لم يستخدم


        if (createdAtDate.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            createdAtDate.isBefore(DateTime(DateTime.now().year, DateTime.now().month + 1, 1))) {
          totalOrdersThisMonth++;
        }

        if (status == 'pending' &&
            createdAtDate.year == now.year &&
            createdAtDate.month == now.month &&
            createdAtDate.day == now.day) {
          pendingOrdersToday++;
        }

        if (status == 'delivered' &&
            createdAtDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            createdAtDate.isBefore(endOfWeek.add(const Duration(days: 1)))) {
          // تأكد من جلب companyShare بشكل صحيح
          final double companyShare = (doc['companyShare'] as num?)?.toDouble() ?? 2000.0;
          estimatedWeeklyProfit += totalPrice - companyShare;
        }
      }

      if (mounted) {
        setState(() {
          _quickStats['إجمالي الطلبات هذا الشهر'] = totalOrdersThisMonth;
          _quickStats['الربح المتوقع هذا الأسبوع'] = estimatedWeeklyProfit.toInt();
          _quickStats['الطلبات المعلقة اليوم'] = pendingOrdersToday;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching quick stats: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ في Firebase أثناء جلب الإحصائيات السريعة: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error fetching quick stats: $e"); // إزالة الأقواس غير الضرورية
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'تعذر جلب الإحصائيات السريعة.', isError: true);
      }
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme; // تم استخدامها الآن

    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // لتحديد اتجاه النص

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("جايك للتوصيل", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
        centerTitle: true,
        // The argument for the named parameter 'drawer' was already specified.
        // إزالة `leading` المكرر
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
                ? Text('${_refreshTimer}s',
                style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface))
                : Icon(Icons.refresh, color: colorScheme.onSurface),
            onPressed: _startRefresh,
            tooltip: 'تحديث البيانات',
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
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      drawer: _buildSidebar(isRtl), // تمرير isRtl إلى Sidebar
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _adImages.isEmpty
                ? Container(
              height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: CircularProgressIndicator(color: colorScheme.primary),
            )
                : Container(
              height: 180,
              margin: const EdgeInsets.only(bottom: 24.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.1).round()), // withOpacity is deprecated
                    spreadRadius: 3,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                alignment: AlignmentDirectional.bottomCenter,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _adImages.length,
                    onPageChanged: (index) {
                    },
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(16.0),
                        child: Image.network(
                          _adImages[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.image_not_supported, size: 50, color: Color.fromRGBO(189, 189, 189, 1)),
                            ),
                          ),
                          loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!.toDouble()
                                      : null,
                                  color: colorScheme.primary,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 10,
                    child: SmoothPageIndicator(
                      controller: _pageController,
                      count: _adImages.length,
                      effect: WormEffect(
                        dotHeight: 10.0,
                        dotWidth: 10.0,
                        activeDotColor: colorScheme.primary,
                        dotColor: Colors.white.withAlpha((255 * 0.6).round()), // withOpacity is deprecated
                        spacing: 6.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Align(
              alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft, // استخدام isRtl
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AllOrderCategoriesScreen()),
                  );
                },
                icon: isRtl ? Icon(Icons.arrow_back_ios_rounded, size: 20, color: colorScheme.primary) : const Icon(Icons.arrow_forward_ios_rounded, size: 20, color: Colors.transparent), // عكس الأيقونة إذا كان RTL، أو جعلها شفافة
                label: Text(
                  "أقسام الطلبات",
                  style: textTheme.titleMedium?.copyWith(color: colorScheme.primary),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  // إذا كانت الأيقونة في اليسار، يمكن إزالة المساحة الزائدة
                  // وإلا، ستحتاج إلى تحديد mainAxisSize.min في Row
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.9,
              ),
              itemCount: 3,
              itemBuilder: (context, index) {
                String title;
                int count;
                Color color;
                String statusFilter;

                if (index == 0) {
                  title = 'المشاكل';
                  count = _problemsCount;
                  color = colorScheme.error;
                  statusFilter = 'reported';
                } else if (index == 1) {
                  title = 'مكتملة';
                  count = _completedCount;
                  color = colorScheme.primary;
                  statusFilter = 'delivered';
                } else {
                  title = 'الطلبات المرتجعة';
                  count = _returnedCount;
                  color = colorScheme.secondary;
                  statusFilter = 'return_requested';
                }

                return _buildOrderStatCard(title, count, color, statusFilter, isRtl); // تمرير isRtl
              },
            ),
            const SizedBox(height: 30.0),

            Align(
              alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft, // استخدام isRtl
              child: Text(
                "إحصائيات سريعة",
                style: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 16.0),
            _buildQuickStatsCards(isRtl), // تمرير isRtl

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
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen()));
              break;
            case 2:
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AddNewOrderScreen()));
              break;
            case 3:
              Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
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
            label: 'إضافة طلب',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'الإشعارات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu),
            label: 'القائمة',
          ),
        ],
      ),
      // drawer: _buildSidebar(), // هذا السطر مكرر، تم إزالة السطر الزائد
    );
  }

  Widget _buildOrderStatCard(String title, int count, Color color, String statusFilter, bool isRtl) { // إضافة isRtl
    final textTheme = Theme.of(context).textTheme;
    final cardTheme = Theme.of(context).cardTheme;

    return Card(
      elevation: cardTheme.elevation,
      shape: cardTheme.shape,
      color: cardTheme.color,
      child: InkWell(
        borderRadius: cardTheme.shape is RoundedRectangleBorder
            ? (cardTheme.shape as RoundedRectangleBorder).borderRadius
            : BorderRadius.circular(12.0),
        onTap: () {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderListScreen(
                status: statusFilter,
                title: title,
                userId: FirebaseAuth.instance.currentUser!.uid,
                userType: 'merchant',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                width: 70,
                height: 70,
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        color: color,
                        value: count.toDouble(),
                        title: '$count',
                        radius: 30,
                        titleStyle: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: color.withAlpha((255 * 0.2).round()), // withOpacity is deprecated
                        value: count == 0 ? 1.0 : 0.0, // لتجنب أن يكون الرسم البياني فارغًا تمامًا إذا كان count صفر
                        title: '',
                        radius: 30,
                      ),
                    ],
                    sectionsSpace: 0,
                    centerSpaceRadius: 25,
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

  Widget _buildQuickStatsCards(bool isRtl) { // إضافة isRtl
    final textTheme = Theme.of(context).textTheme;
    final cardTheme = Theme.of(context).cardTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: _quickStats.keys.map((key) {
        Color statColor;
        IconData statIcon;
        if (key.contains('الربح')) {
          statColor = colorScheme.primary;
          statIcon = Icons.monetization_on_outlined;
        } else if (key.contains('المعلقة')) {
          statColor = colorScheme.secondary;
          statIcon = Icons.access_time_filled;
        } else {
          statColor = Colors.blue;
          statIcon = Icons.list_alt;
        }

        return Card(
          elevation: cardTheme.elevation,
          margin: const EdgeInsets.only(bottom: 12.0),
          shape: cardTheme.shape,
          color: cardTheme.color,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  key.contains('الربح') ? '${_quickStats[key].toString()} د.ع' : _quickStats[key].toString(),
                  style: textTheme.titleLarge?.copyWith(
                    color: statColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.ltr, // يفضل LTR للأرقام
                ),
                Row(
                  children: [
                    Text(
                      key,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                    ),
                    const SizedBox(width: 12),
                    Icon(statIcon, color: statColor, size: 36),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
                  "مرحباً مجدداً",
                  style: textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                ),
                const SizedBox(height: 4.0),
                Text(
                  _merchantName,
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
            leading: const Icon(Icons.person),
            title: Text('الملف الشخصي', textAlign: isRtl ? TextAlign.right : TextAlign.left, style: textTheme.bodyMedium), // استخدام isRtl
            onTap: () {
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MerchantProfileScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: Text('الإحصائيات', textAlign: isRtl ? TextAlign.right : TextAlign.left, style: textTheme.bodyMedium), // استخدام isRtl
            onTap: () {
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MerchantReportsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: Text('المحاسبة', textAlign: isRtl ? TextAlign.right : TextAlign.left, style: textTheme.bodyMedium), // استخدام isRtl
            onTap: () {
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MerchantSettlementScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: Text('الدعم الفني', textAlign: isRtl ? TextAlign.right : TextAlign.left, style: textTheme.bodyMedium), // استخدام isRtl
            onTap: () {
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => SupportChatScreen(
                targetUserId: FirebaseAuth.instance.currentUser!.uid,
                targetUserName: _merchantName,
              )));
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text('تسجيل الخروج', textAlign: isRtl ? TextAlign.right : TextAlign.left, style: textTheme.bodyMedium), // استخدام isRtl
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