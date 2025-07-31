import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'admin_user_profile_screen.dart'; // هذا الاستيراد ضروري لاستخدام AdminUserProfileScreen
import '../../common/custom_snackbar.dart'; // افتراض وجود showCustomSnackBar

class AdminSettlementHistoryScreen extends StatefulWidget {
  final String? userId;
  final String? userType;

  const AdminSettlementHistoryScreen({super.key, this.userId, this.userType});

  @override
  State<AdminSettlementHistoryScreen> createState() => _AdminSettlementHistoryScreenState();
}

class _AdminSettlementHistoryScreenState extends State<AdminSettlementHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  String _selectedUserTypeFilter = 'all';
  String? _selectedUserIdFilter;
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime.now();

  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchUserNames();
    if (widget.userId != null) {
      _selectedUserIdFilter = widget.userId;
      _selectedUserTypeFilter = widget.userType ?? 'all';
    }
  }

  Future<void> _fetchUserNames() async {
    try {
      final QuerySnapshot usersSnapshot = await _firestore.collection('users').get();
      final Map<String, String> names = {};
      for (final doc in usersSnapshot.docs) {
        names[doc.id] = doc['name'] ?? doc['storeName'] ?? 'غير معروف';
      }
      if (mounted) {
        setState(() {
          _userNames = names;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user names for history: $e"); // إزالة الأقواس
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
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
          title: Text("سجل التحاسب", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    Query query = _firestore.collection('settlements');

    if (_selectedUserTypeFilter != 'all') {
      query = query.where('userType', isEqualTo: _selectedUserTypeFilter);
    }
    if (_selectedUserIdFilter != null && _selectedUserIdFilter!.isNotEmpty) {
      query = query.where('userId', isEqualTo: _selectedUserIdFilter);
    }

    query = query
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_endDate.add(const Duration(days: 1))))
        .orderBy('date', descending: true);

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: isRtl ? MainAxisAlignment.end : MainAxisAlignment.start, // استخدام isRtl
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color.fromRGBO(189, 189, 189, 1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        hint: Text('كل الأنواع', style: textTheme.bodyMedium),
                        value: _selectedUserTypeFilter == 'all' ? null : _selectedUserTypeFilter,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedUserTypeFilter = newValue ?? 'all';
                            _selectedUserIdFilter = null;
                          });
                        },
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('كل الأنواع', style: TextStyle(fontFamily: 'Cairo'))),
                          DropdownMenuItem(value: 'merchant', child: Text('التجار', style: TextStyle(fontFamily: 'Cairo'))),
                          DropdownMenuItem(value: 'driver', child: Text('المندوبين', style: TextStyle(fontFamily: 'Cairo'))),
                        ],
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                        icon: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  if (_selectedUserTypeFilter != 'all')
                    FutureBuilder<List<DropdownMenuItem<String>>>(
                      future: _getUserDropdownItems(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            width: 120,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        if (snapshot.hasError) {
                          return Text('خطأ', style: textTheme.bodySmall?.copyWith(color: colorScheme.error));
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color.fromRGBO(189, 189, 189, 1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              hint: Text(
                                  'اختر ${_selectedUserTypeFilter == 'merchant' ? 'تاجراً' : 'مندوباً'}',
                                  style: textTheme.bodyMedium),
                              value: _selectedUserIdFilter,
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedUserIdFilter = newValue;
                                });
                              },
                              items: snapshot.data,
                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                              icon: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                              isExpanded: true,
                              menuMaxHeight: MediaQuery.of(context).size.height * 0.4,
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(width: 8),

                  ElevatedButton.icon(
                    onPressed: () => _selectDateRange(context),
                    icon: Icon(Icons.calendar_today, color: colorScheme.onPrimary),
                    label: Text(
                      '${DateFormat('yyyy-MM-dd').format(_startDate)} - ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                      style: textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),

                  IconButton(
                    icon: Icon(Icons.refresh, color: colorScheme.primary),
                    onPressed: _fetchUserNames,
                    tooltip: 'تحديث الأسماء والفلاتر',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                }
                if (snapshot.hasError) {
                  debugPrint("Settlement Stream Error: ${snapshot.error}");
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'حدث خطأ أثناء جلب سجلات التحاسب: ${snapshot.error}',
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
                          'لا توجد سجلات تحاسب مطابقة للمعايير.',
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
                    final DocumentSnapshot settlementDoc = snapshot.data!.docs[index];
                    final String userId = settlementDoc['userId'] as String;
                    final String userName = _userNames[userId] ?? 'مستخدم غير معروف';
                    final String userType = settlementDoc['userType'] as String? ?? 'غير معروف';
                    final DateTime settlementDate = (settlementDoc['date'] as Timestamp).toDate();
                    final double amount = (settlementDoc['totalAmount'] as num?)?.toDouble() ?? 0.0;
                    final String status = settlementDoc['status'] as String? ?? 'unknown';

                    final Color statusColor = _getStatusColor(status, colorScheme);

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
                          '${userType == 'driver' ? 'تحاسب مندوب' : 'تحاسب تاجر'}: $userName',
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                        ),
                        subtitle: Text(
                          'المبلغ: ${amount.toStringAsFixed(0)} دينار | الحالة: ${_translateSettlementStatus(status)}',
                          style: textTheme.bodyMedium?.copyWith(color: statusColor),
                          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                        ),
                        childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        children: [
                          Column(
                            crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // استخدام isRtl
                            children: [
                              Text(
                                'تاريخ التحاسب: ${DateFormat('yyyy-MM-dd').format(settlementDate)}',
                                style: textTheme.bodySmall?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                              ),
                              const SizedBox(height: 8.0),
                              Text('الطلبات المشمولة:',
                                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr), // استخدام isRtl
                              if (settlementDoc['orderIds'] != null && (settlementDoc['orderIds'] as List).isNotEmpty)
                                // تم إزالة .toList() غير الضرورية
                                ... (settlementDoc['orderIds'] as List<dynamic>).map((orderId) =>
                                    Text(
                                      '#$orderId',
                                      style: textTheme.bodySmall,
                                      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                                    ),
                                )
                              else
                                Text(
                                  'لا توجد طلبات مرتبطة بهذا التحاسب.',
                                  style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                                ),
                              const SizedBox(height: 8.0),
                              if (settlementDoc['approvedByAdminId'] != null)
                                Text('تمت الموافقة بواسطة: ${settlementDoc['approvedByAdminName'] ?? 'الإدارة'}',
                                  style: textTheme.bodySmall?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                                  textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                                ),
                              if (settlementDoc['paidByAdminId'] != null)
                                Text('تم الدفع بواسطة: ${settlementDoc['paidByAdminName'] ?? 'الإدارة'}',
                                  style: textTheme.bodySmall?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                                  textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                                ),
                              const SizedBox(height: 12.0),
                              Align(
                                alignment: isRtl ? Alignment.bottomLeft : Alignment.bottomRight, // استخدام isRtl
                                child: TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(
                                        builder: (context) => AdminUserProfileScreen(userId: userId)));
                                  },
                                  icon: Icon(Icons.person, size: 20, color: colorScheme.primary),
                                  label: Text('عرض ملف المستخدم', style: textTheme.labelLarge?.copyWith(color: colorScheme.primary)),
                                ),
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
          ),
        ],
      ),
    );
  }

  Future<List<DropdownMenuItem<String>>> _getUserDropdownItems() async {
    final List<DropdownMenuItem<String>> items = <DropdownMenuItem<String>>[
      // التحقق من mounted قبل استخدام context
      if (mounted)
        DropdownMenuItem(value: null, child: Text('كل المستخدمين', style: Theme.of(context).textTheme.bodyMedium)),
    ];

    try {
      final QuerySnapshot usersSnapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: _selectedUserTypeFilter)
          .get();

      for (final doc in usersSnapshot.docs) {
        items.add(DropdownMenuItem(
          value: doc.id,
          // التحقق من mounted قبل استخدام context
          child: Text(doc['name'] ?? doc['storeName'] ?? 'غير معروف',
              style: mounted ? Theme.of(context).textTheme.bodyMedium : const TextStyle()),
        ));
      }
    } catch (e) {
      debugPrint("Error fetching users for dropdown: $e"); // إزالة الأقواس
    }

    return items;
  }

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'pending_admin_approval': return Colors.orange;
      case 'approved': return Colors.green;
      case 'paid': return colorScheme.primary;
      default: return Colors.grey;
    }
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