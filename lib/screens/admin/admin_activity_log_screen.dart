import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';


class AdminActivityLogScreen extends StatefulWidget {
  const AdminActivityLogScreen({super.key});

  @override
  State<AdminActivityLogScreen> createState() => _AdminActivityLogScreenState();
}

class _AdminActivityLogScreenState extends State<AdminActivityLogScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all';
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // لتحديد اتجاه النص

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "سجل الإجراءات الإدارية",
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _buildFilterSection(textTheme, colorScheme, isRtl), // تمرير isRtl
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildActivityLogStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ: ${snapshot.error}',
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                      textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, size: 60, color: Color.fromRGBO(189, 189, 189, 1)), // استخدام const
                        const SizedBox(height: 8),
                        Text(
                          'لا توجد سجلات للإجراءات الإدارية حالياً.',
                          style: textTheme.titleMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                        ),
                      ],
                    ),
                  );
                }

                final activities = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return _buildActivityCard(activity, textTheme, colorScheme, isRtl); // تمرير isRtl
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(TextTheme textTheme, ColorScheme colorScheme, bool isRtl) { // إضافة isRtl
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.stretch : CrossAxisAlignment.stretch, // يمكن أن يكون CrossAxisAlignment.stretch
        children: [
          Text(
            'تصفية السجلات:',
            style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedFilter,
            decoration: InputDecoration(
              labelText: 'نوع الإجراء',
              filled: Theme.of(context).inputDecorationTheme.filled,
              fillColor: Theme.of(context).inputDecorationTheme.fillColor,
              border: Theme.of(context).inputDecorationTheme.border,
              enabledBorder: Theme.of(context).inputDecorationTheme.enabledBorder,
              focusedBorder: Theme.of(context).inputDecorationTheme.focusedBorder,
              labelStyle: Theme.of(context).inputDecorationTheme.labelStyle,
              hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
              contentPadding: Theme.of(context).inputDecorationTheme.contentPadding,
            ),
            style: textTheme.bodyMedium,
            alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft, // استخدام isRtl
            items: const [
              DropdownMenuItem(value: 'all', child: Text('كل الإجراءات')), // لا داعي لـ TextAlign.right داخل DropdownMenuItem
              DropdownMenuItem(value: 'order_management', child: Text('إدارة الطلبات')),
              DropdownMenuItem(value: 'user_management', child: Text('إدارة المستخدمين')),
              DropdownMenuItem(value: 'financial_settlement', child: Text('التحاسب المالي')),
              DropdownMenuItem(value: 'ads_notifications', child: Text('الإعلانات والإشعارات')),
              DropdownMenuItem(value: 'reports_analytics', child: Text('التقارير والتحليلات')),
            ],
            onChanged: (String? newValue) {
              if (mounted) {
                setState(() {
                  _selectedFilter = newValue!;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: colorScheme.primary,
                        onPrimary: colorScheme.onPrimary,
                        onSurface: colorScheme.onSurface,
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                        ),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null && mounted) {
                setState(() {
                  _selectedDate = picked;
                });
              }
            },
            icon: const Icon(Icons.calendar_today),
            label: Text(
              _selectedDate == null
                  ? 'اختر تاريخاً'
                  : 'التاريخ: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
              style: textTheme.labelLarge,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_selectedDate != null)
            TextButton(
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _selectedDate = null;
                  });
                }
              },
              child: Text('مسح التاريخ', style: textTheme.labelMedium?.copyWith(color: colorScheme.error)),
            ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildActivityLogStream() {
    Query query = _firestore.collection('admin_activity_log').orderBy('timestamp', descending: true);

    if (_selectedFilter != 'all') {
      query = query.where('category', isEqualTo: _selectedFilter);
    }

    if (_selectedDate != null) {
      final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      query = query
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay));
    }

    return query.snapshots();
  }

  Widget _buildActivityCard(DocumentSnapshot activity, TextTheme textTheme, ColorScheme colorScheme, bool isRtl) { // إضافة isRtl
    final data = activity.data() as Map<String, dynamic>;
    // final String adminId = data['adminId'] ?? 'غير معروف'; // تم إزالة المتغير غير المستخدم
    final String adminName = data['adminName'] ?? 'المسؤول';
    final String action = data['action'] ?? 'إجراء غير محدد';
    final String category = data['category'] ?? 'عام';
    final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
    final String details = data['details'] ?? 'لا توجد تفاصيل إضافية.';

    final DateTime dateTime = timestamp.toDate();
    final String formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);

    IconData icon;
    Color iconColor;
    switch (category) {
      case 'order_management':
        icon = Icons.receipt_long;
        iconColor = colorScheme.primary;
        break;
      case 'user_management':
        icon = Icons.people;
        iconColor = Colors.teal;
        break;
      case 'financial_settlement':
        icon = Icons.account_balance_wallet;
        iconColor = Colors.green;
        break;
      case 'ads_notifications':
        icon = Icons.campaign;
        iconColor = Colors.orange;
        break;
      case 'reports_analytics':
        icon = Icons.bar_chart;
        iconColor = Colors.blueGrey;
        break;
      default:
        icon = Icons.info_outline;
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // استخدام isRtl
          children: [
            Row(
              mainAxisAlignment: isRtl ? MainAxisAlignment.end : MainAxisAlignment.start, // استخدام isRtl
              children: [
                Text(
                  adminName,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                ),
                const SizedBox(width: 8),
                Icon(icon, color: iconColor, size: 24),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              action,
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
            ),
            const SizedBox(height: 4),
            Text(
              details,
              style: textTheme.bodySmall?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
            ),
            const SizedBox(height: 8),
            Align(
              alignment: isRtl ? Alignment.bottomRight : Alignment.bottomLeft, // استخدام isRtl
              child: Text(
                formattedDate,
                style: textTheme.labelSmall?.copyWith(color: const Color.fromRGBO(158, 158, 158, 1)),
                textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                textDirection: isRtl ? TextDirection.ltr : TextDirection.ltr, // يفضل LTR للتاريخ/الوقت
              ),
            ),
          ],
        ),
      ),
    );
  }
}