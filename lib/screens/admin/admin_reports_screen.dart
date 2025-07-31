import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart'; // للرسوم البيانية
import 'package:intl/intl.dart'; // لتنسيق التاريخ

// هذا الاستيراد غير مستخدم في هذا الملف، يمكن إزالته
// import '../admin/admin_user_profile_screen.dart';
// هذا الاستيراد غير مستخدم في هذا الملف، يمكن إزالته
// import 'order_details_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // متغيرات لتخزين بيانات التقارير
  int _totalOrders = 0;
  int _completedOrders = 0;
  int _reportedOrders = 0;
  int _returnedOrders = 0;
  double _totalCompanyRevenue = 0.0;
  double _totalRevenue = 0.0; // إجمالي مبلغ الطلبات المكتملة
  double _companyShare = 0.0; // حصة الشركة من الطلبات المكتملة
  double _merchantProfit = 0.0; // صافي ربح التاجر من الطلبات المكتملة

  // متغيرات الفلترة التاريخية
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1); // بداية الشهر الحالي
  DateTime _endDate = DateTime.now(); // اليوم الحالي

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    if (!mounted) return;

    setState(() {
      // إعادة تعيين القيم أثناء جلب البيانات
      _totalOrders = 0;
      _completedOrders = 0;
      _reportedOrders = 0;
      _returnedOrders = 0;
      _totalCompanyRevenue = 0.0;
      _totalRevenue = 0.0; // إعادة تعيين
      _companyShare = 0.0; // إعادة تعيين
      _merchantProfit = 0.0; // إعادة تعيين
    });

    try {
      QuerySnapshot ordersSnapshot = await _firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate.add(const Duration(days: 1)))) // لتضمين اليوم الأخير كاملاً
          .get();

      for (var doc in ordersSnapshot.docs) {
        _totalOrders++;
        String status = doc['status'];
        String orderType = doc['orderType'] ?? 'normal';

        if (status == 'delivered') {
          _completedOrders++;
          double orderTotalPrice = (doc['totalPrice'] as num?)?.toDouble() ?? 0.0;
          double orderCompanyShare = (doc['companyShare'] as num?)?.toDouble() ?? 0.0;

          _totalCompanyRevenue += orderCompanyShare; // حصة الشركة من كل طلب
          _totalRevenue += orderTotalPrice;
          _companyShare += orderCompanyShare;
          _merchantProfit += (orderTotalPrice - orderCompanyShare);

          if (orderType == 'replacement' && (doc['isReturnConfirmedByMerchant'] == true)) {
            _returnedOrders++;
          }
        } else if (status == 'reported') {
          _reportedOrders++;
        } else if (status == 'return_requested') {
          _returnedOrders++;
        }
      }

      if (mounted) {
        setState(() {}); // تحديث الواجهة بالبيانات الجديدة
      }
    } catch (e) {
      print("Error fetching report data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر جلب بيانات التقرير.', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1), // أقدم تاريخ ممكن
      lastDate: DateTime.now().add(const Duration(days: 30)), // إلى شهر من الآن
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blueAccent, // لون الثيم
            colorScheme: const ColorScheme.light(primary: Colors.blueAccent),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(fontFamily: 'Cairo'), // تطبيق الخط
              labelLarge: TextStyle(fontFamily: 'Cairo'), // تطبيق الخط
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && (picked.start != _startDate || picked.end != _endDate) && mounted) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchReportData(); // إعادة جلب البيانات للفترة الجديدة
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // لتحديد اتجاه النص

    // يجب التأكد أن _currentUser ليس null هنا.
    // إذا كنت تستخدم Authentication في تطبيقك، فغالباً ما يتم تحويل المستخدم إلى شاشة تسجيل الدخول
    // إذا كان _currentUser null. لذلك، هذا التحقق قد لا يكون مطلوباً بالضرورة هنا.
    if (_auth.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("التقارير", style: TextStyle(fontFamily: 'Cairo'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("التقارير", style: Theme.of(context).appBarTheme.titleTextStyle),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: Theme.of(context).appBarTheme.iconTheme?.color,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // فلترة التاريخ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  label: Text(
                    'من ${DateFormat('yyyy-MM-dd').format(_startDate)} إلى ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                    style: const TextStyle(color: Colors.blueAccent, fontFamily: 'Cairo'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blueAccent),
                  onPressed: _fetchReportData,
                ),
              ],
            ),
            const SizedBox(height: 24.0),

            // ملخص التقارير المالية
            _buildSectionHeader("ملخص مالي", isRtl),
            _buildSummaryCard('إجمالي الطلبات المكتملة', _completedOrders.toString(), Icons.check_circle, Colors.green, isRtl),
            _buildSummaryCard('مبلغ الطلبات المكتملة', '${_totalRevenue.toInt()} دينار', Icons.attach_money, Colors.blue, isRtl),
            _buildSummaryCard('مبلغ الشركة', '${_companyShare.toInt()} دينار', Icons.account_balance, Colors.orange, isRtl),
            _buildSummaryCard('صافي ربحك', '${_merchantProfit.toInt()} دينار', Icons.wallet_giftcard, Colors.purple, isRtl),
            const SizedBox(height: 24.0),

            // توزيع الطلبات (مخطط دائري)
            _buildSectionHeader("توزيع الطلبات", isRtl),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: _buildPieChartSections(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  borderData: FlBorderData(show: false),
                  pieTouchData: PieTouchData(touchCallback: (flTouchEvent, pieTouchResponse) {
                    // يمكن إضافة تفاعل عند اللمس هنا
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            _buildLegend(isRtl), // مفتاح الرسم البياني
          ],
        ),
      ),
    );
  }

  // مكونات مساعدة
  Widget _buildSectionHeader(String title, bool isRtl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent, fontFamily: 'Cairo'),
        textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isRtl) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: ListTile(
        leading: isRtl ? Text( // تبديل مكان النص والقيمة ليتناسب مع RTL
          value,
          style: const TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ) : Icon(icon, color: color, size: 30),
        trailing: isRtl ? Icon(icon, color: color, size: 30) : Text( // تبديل مكان النص والقيمة ليتناسب مع RTL
          value,
          style: const TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    int total = _totalOrders;
    if (total == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey,
          value: 100,
          title: 'لا بيانات',
          radius: 50,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo'),
        ),
      ];
    }

    // حساب نسبة كل جزء
    return [
      if (_completedOrders > 0)
        PieChartSectionData(
          color: Colors.green,
          value: (_completedOrders / total) * 100,
          title: 'مكتملة\n${((_completedOrders / total) * 100).toStringAsFixed(1)}%',
          radius: 50,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo'),
        ),
      if (_reportedOrders > 0)
        PieChartSectionData(
          color: Colors.red,
          value: (_reportedOrders / total) * 100,
          title: 'مشاكل\n${((_reportedOrders / total) * 100).toStringAsFixed(1)}%',
          radius: 50,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo'),
        ),
      if (_returnedOrders > 0)
        PieChartSectionData(
          color: Colors.orange,
          value: (_returnedOrders / total) * 100,
          title: 'مرتجعة\n${((_returnedOrders / total) * 100).toStringAsFixed(1)}%',
          radius: 50,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo'),
        ),
      // يمكن إضافة باقي الحالات الأخرى هنا إذا أردت إظهارها في المخطط الدائري
      // مثلاً الطلبات "المسجلة" و "قيد التوصيل"
    ];
  }

  // مفتاح الرسم البياني
  Widget _buildLegend(bool isRtl) {
    return Row(
      mainAxisAlignment: isRtl ? MainAxisAlignment.center : MainAxisAlignment.center,
      children: [
        _buildLegendItem(Colors.green, 'مكتملة', isRtl),
        _buildLegendItem(Colors.red, 'مشاكل', isRtl),
        _buildLegendItem(Colors.orange, 'مرتجعة', isRtl),
        // أضف المزيد حسب الأقسام في المخطط الدائري
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text, bool isRtl) {
    return Row(
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, fontFamily: 'Cairo')),
        const SizedBox(width: 8),
      ],
    );
  }
}
