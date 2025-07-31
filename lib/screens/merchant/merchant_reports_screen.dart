import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// هذا الاستيراد يبدو غير مستخدم بشكل مباشر هنا في MerchantReportsScreen
// import '../admin/admin_user_profile_screen.dart';
// افتراض وجود showCustomSnackBar في common/custom_snackbar.dart
import '../../common/custom_snackbar.dart';


class MerchantReportsScreen extends StatefulWidget {
  const MerchantReportsScreen({super.key});

  @override
  State<MerchantReportsScreen> createState() => _MerchantReportsScreenState();
}

class _MerchantReportsScreenState extends State<MerchantReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  int _totalOrders = 0;
  int _completedOrders = 0;
  int _cancelledOrders = 0;
  int _returnedOrders = 0;
  int _reportedOrders = 0; // تم تعريف المتغير هنا

  double _totalRevenue = 0.0;
  double _companyShare = 0.0;
  double _merchantProfit = 0.0;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _fetchReportData();
    }
  }

  Future<void> _fetchReportData() async {
    if (!mounted || _currentUser == null) return;

    setState(() {
      _totalOrders = 0;
      _completedOrders = 0;
      _cancelledOrders = 0;
      _returnedOrders = 0;
      _reportedOrders = 0; // إعادة تعيين
      _totalRevenue = 0.0;
      _companyShare = 0.0;
      _merchantProfit = 0.0;
    });

    try {
      final QuerySnapshot ordersSnapshot = await _firestore
          .collection('orders')
          .where('merchantId', isEqualTo: _currentUser!.uid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate.add(const Duration(days: 1))))
          .get();

      for (final doc in ordersSnapshot.docs) {
        _totalOrders++;
        final String status = doc['status'] as String? ?? 'unknown';
        final String orderType = doc['orderType'] as String? ?? 'normal';
        final double price = (doc['totalPrice'] as num?)?.toDouble() ?? 0.0;
        // final double _ = (doc['deliveryCost'] as num?)?.toDouble() ?? 0.0; // هذا المتغير لم يستخدم

        if (status == 'delivered') {
          _completedOrders++;
          _totalRevenue += price;
          _companyShare += (doc['companyShare'] as num?)?.toDouble() ?? 2000.0;
          _merchantProfit += (price - ((doc['companyShare'] as num?)?.toDouble() ?? 2000.0));

          if (orderType == 'replacement' && (doc['isReturnConfirmedByMerchant'] as bool? ?? false)) {
            _returnedOrders++;
          }
        } else if (status == 'reported') { // تم إضافة هذه الحالة
          _reportedOrders++;
        } else if (status == 'cancelled') {
          _cancelledOrders++;
        }
        // يمكن أن يكون الطلب مرتجعًا حتى لو لم يكن مكتملًا
        if (status == 'return_requested' || status == 'return_completed') {
          _returnedOrders++;
        }
      }

      if (mounted) {
        setState(() {});
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching merchant report data: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ في Firebase أثناء جلب بيانات التقرير: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("General Error fetching merchant report data: $e"); // إزالة الأقواس غير الضرورية
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'تعذر جلب بيانات التقرير.', isError: true);
      }
    }
  }

  Future<void> _selectDateRange() async {
    final ThemeData theme = Theme.of(context);

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
            textTheme: theme.textTheme.copyWith(
              bodyMedium: theme.textTheme.bodyMedium,
              labelLarge: theme.textTheme.labelLarge,
            ),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: theme.colorScheme.surface,
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
      _fetchReportData();
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
          title: Text("التقارير", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("التقارير", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
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
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.1).round()), // withOpacity is deprecated
                    blurRadius: 5,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectDateRange,
                      icon: Icon(Icons.calendar_today, color: colorScheme.onPrimary),
                      label: FittedBox(
                        child: Text(
                          '${DateFormat('yyyy-MM-dd').format(_startDate)} - ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                          style: textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.refresh, color: colorScheme.primary, size: 30),
                    onPressed: _fetchReportData,
                    tooltip: 'تحديث البيانات',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            _buildSectionHeader("ملخص مالي", isRtl), // تمرير isRtl
            _buildSummaryCard(context, 'إجمالي الطلبات المكتملة', _completedOrders.toString(), Icons.check_circle, Colors.green, isRtl), // تمرير isRtl
            _buildSummaryCard(context, 'مبلغ الطلبات المكتملة', '${_totalRevenue.toInt()} دينار', Icons.attach_money, colorScheme.primary, isRtl), // تمرير isRtl
            _buildSummaryCard(context, 'مبلغ الشركة', '${_companyShare.toInt()} دينار', Icons.account_balance, colorScheme.secondary, isRtl), // تمرير isRtl
            _buildSummaryCard(context, 'صافي ربحك', '${_merchantProfit.toInt()} دينار', Icons.wallet_giftcard, Colors.purple, isRtl), // تمرير isRtl
            const SizedBox(height: 24.0),

            _buildSectionHeader("توزيع الطلبات", isRtl), // تمرير isRtl
            Container(
              height: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardTheme.color,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.1).round()), // withOpacity is deprecated
                    blurRadius: 5,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: _totalOrders == 0
                  ? Center(
                child: Text(
                  'لا توجد بيانات للرسوم البيانية في هذا النطاق الزمني.',
                  style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                ),
              )
                  : PieChart(
                PieChartData(
                  sections: _buildPieChartSections(colorScheme, textTheme), // تمرير textTheme
                  sectionsSpace: 4,
                  centerSpaceRadius: 60,
                  borderData: FlBorderData(show: false),
                  pieTouchData: PieTouchData(touchCallback: (flTouchEvent, pieTouchResponse) {
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            _buildLegend(textTheme, colorScheme, isRtl), // تمرير isRtl
            const SizedBox(height: 24.0),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isRtl) { // إضافة isRtl
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
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

  Widget _buildSummaryCard(BuildContext context, String title, String value, IconData icon, Color color, bool isRtl) { // إضافة isRtl
    final textTheme = Theme.of(context).textTheme;
    final cardTheme = Theme.of(context).cardTheme;

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
              value,
              style: textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.ltr, // يفضل LTR للأرقام
            ),
            Row(
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                ),
                const SizedBox(width: 12),
                Icon(icon, color: color, size: 36),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(ColorScheme colorScheme, TextTheme textTheme) { // إضافة textTheme
    int total = _totalOrders;
    if (total == 0) {
      return [
        PieChartSectionData(
          color: const Color.fromRGBO(189, 189, 189, 1),
          value: 100,
          title: 'لا بيانات',
          radius: 60,
          titleStyle: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ];
    }

    // حساب نسبة كل جزء
    final double completedPercentage = (_completedOrders / total) * 100;
    final double cancelledPercentage = (_cancelledOrders / total) * 100;
    final double reportedPercentage = (_reportedOrders / total) * 100;
    final double returnedPercentage = (_returnedOrders / total) * 100;
    // تأكد من أن مجموع النسب لا يتجاوز 100
    double otherPercentage = 100.0 - completedPercentage - cancelledPercentage - reportedPercentage - returnedPercentage;
    if (otherPercentage < 0) otherPercentage = 0; // لمنع القيم السالبة بسبب التقريب أو حالات خاصة


    return [
      if (_completedOrders > 0)
        PieChartSectionData(
          color: Colors.green,
          value: completedPercentage,
          title: '${completedPercentage.toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (_cancelledOrders > 0)
        PieChartSectionData(
          color: colorScheme.error,
          value: cancelledPercentage,
          title: '${cancelledPercentage.toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (_reportedOrders > 0)
        PieChartSectionData(
          color: Colors.red, // يمكن أن يكون لون مختلف عن cancelled إذا أردت التمييز
          value: reportedPercentage,
          title: '${reportedPercentage.toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (_returnedOrders > 0)
        PieChartSectionData(
          color: colorScheme.secondary,
          value: returnedPercentage,
          title: '${returnedPercentage.toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (otherPercentage > 0)
        PieChartSectionData(
          color: Colors.blueGrey,
          value: otherPercentage,
          title: '${otherPercentage.toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
    ];
  }

  Widget _buildLegend(TextTheme textTheme, ColorScheme colorScheme, bool isRtl) { // إضافة isRtl
    return Wrap(
      alignment: isRtl ? WrapAlignment.end : WrapAlignment.start, // استخدام isRtl
      spacing: 12.0,
      runSpacing: 8.0,
      children: [
        _buildLegendItem(Colors.green, 'مكتملة', textTheme, isRtl), // تمرير isRtl
        _buildLegendItem(colorScheme.error, 'ملغاة', textTheme, isRtl), // تغيير النص ليعكس 'cancelled'
        _buildLegendItem(Colors.red, 'مشاكل', textTheme, isRtl), // إضافة مشاكل
        _buildLegendItem(colorScheme.secondary, 'مرتجعة', textTheme, isRtl), // تمرير isRtl
        _buildLegendItem(Colors.blueGrey, 'أخرى', textTheme, isRtl), // تمرير isRtl
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text, TextTheme textTheme, bool isRtl) { // إضافة isRtl
    return Row(
      mainAxisSize: MainAxisSize.min,
      // تبديل ترتيب الأيقونة والنص بناءً على isRtl
      children: isRtl
          ? [
        Text(text, style: textTheme.bodyMedium),
        const SizedBox(width: 8),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ]
          : [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: textTheme.bodyMedium),
      ],
    );
  }
}