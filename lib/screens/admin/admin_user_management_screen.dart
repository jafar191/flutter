import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_user_profile_screen.dart';
import 'admin_user_creation_screen.dart';
// افتراض وجود هذه الدالة في ملف common/custom_snackbar.dart
import '../../common/custom_snackbar.dart';


class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<DocumentSnapshot> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAllUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllUsers() async {
    try {
      QuerySnapshot usersSnapshot = await _firestore.collection('users').get();
      if (mounted) {
        setState(() {
          _allUsers = usersSnapshot.docs;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching all users: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ في Firebase أثناء جلب قائمة المستخدمين: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error fetching all users: $e"); // إزالة الأقواس غير الضرورية
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'تعذر جلب قائمة المستخدمين.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    final String searchText = _searchController.text.toLowerCase();

    List<DocumentSnapshot> filteredMerchants = _allUsers.where((userDoc) {
      if (userDoc['userType'] != 'merchant') return false;

      final String name = (userDoc['name'] ?? userDoc['storeName'] ?? '').toLowerCase();
      final String phone = (userDoc['phone'] ?? '').toLowerCase();
      return name.contains(searchText) || phone.contains(searchText);
    }).toList();

    List<DocumentSnapshot> filteredDrivers = _allUsers.where((userDoc) {
      if (userDoc['userType'] != 'driver') return false;

      final String name = (userDoc['name'] ?? '').toLowerCase();
      final String phone = (userDoc['phone'] ?? '').toLowerCase();
      return userDoc['userType'] == 'driver' && (name.contains(searchText) || phone.contains(searchText));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "إدارة المستخدمين",
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        ),
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
          unselectedLabelColor: Colors.grey[600],
          labelStyle: textTheme.labelLarge,
          unselectedLabelStyle: textTheme.labelMedium,
          tabs: const [
            Tab(text: "التجار", icon: Icon(Icons.store)),
            Tab(text: "المندوبين", icon: Icon(Icons.delivery_dining)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'ابحث بالاسم أو رقم الهاتف',
                hintText: 'ادخل الاسم أو الرقم للبحث...',
                prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  color: Colors.grey,
                )
                    : null,
                filled: Theme.of(context).inputDecorationTheme.filled,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                border: Theme.of(context).inputDecorationTheme.border,
                enabledBorder: Theme.of(context).inputDecorationTheme.enabledBorder,
                focusedBorder: Theme.of(context).inputDecorationTheme.focusedBorder,
                labelStyle: Theme.of(context).inputDecorationTheme.labelStyle,
                hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                contentPadding: Theme.of(context).inputDecorationTheme.contentPadding,
              ),
              onChanged: (value) {
                setState(() {});
              },
              style: textTheme.bodyMedium,
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                final String userType = _tabController.index == 0 ? 'merchant' : 'driver';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminUserCreationScreen(
                      userTypeToCreate: userType,
                    ),
                  ),
                ).then((value) {
                  if (value == true) {
                    _fetchAllUsers();
                    // التحقق من mounted قبل استخدام context
                    if (mounted) {
                      showCustomSnackBar(context, 'تم إنشاء مستخدم جديد بنجاح!', isSuccess: true);
                    }
                  }
                });
              },
              icon: Icon(Icons.person_add, color: colorScheme.onPrimary),
              label: Text(
                _tabController.index == 0 ? 'إنشاء حساب تاجر جديد' : 'إنشاء حساب مندوب جديد',
                style: textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(filteredMerchants, 'merchant', isRtl), // تمرير isRtl
                _buildUserList(filteredDrivers, 'driver', isRtl), // تمرير isRtl
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<DocumentSnapshot> users, String userType, bool isRtl) { // إضافة isRtl كمعلمة
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme;

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              userType == 'merchant' ? Icons.store_mall_directory_outlined : Icons.delivery_dining_outlined,
              size: 80,
              color: const Color.fromRGBO(189, 189, 189, 1),
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد ${userType == 'merchant' ? 'تجار' : 'مندوبون'} حالياً أو لا يوجد تطابق للبحث.',
              style: textTheme.titleMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: users.length,
      itemBuilder: (context, index) {
        DocumentSnapshot userDoc = users[index];
        String name = userDoc['name'] ?? userDoc['storeName'] ?? 'اسم غير معروف';
        String phone = userDoc['phone'] ?? 'رقم غير متوفر';
        String status = userDoc['status'] ?? 'active';

        Color statusColor = Colors.grey;
        if (status == 'active') {
          statusColor = colorScheme.primary;
        } else if (status == 'suspended') {
          statusColor = colorScheme.secondary;
        } else if (status == 'deleted') {
          statusColor = colorScheme.error;
        }

        return Card(
          elevation: cardTheme.elevation,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape: cardTheme.shape,
          color: cardTheme.color,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            leading: Icon(
              userType == 'merchant' ? Icons.store : Icons.delivery_dining,
              color: colorScheme.primary,
              size: 30,
            ),
            title: Text(
              name,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
            ),
            subtitle: Column(
              crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // استخدام isRtl
              children: [
                Text(
                  'الهاتف: $phone',
                  style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                ),
                Text(
                  'الحالة: ${_translateUserStatus(status)}',
                  style: textTheme.bodySmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: Color.fromRGBO(189, 189, 189, 1)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminUserProfileScreen(userId: userDoc.id),
                ),
              ).then((value) {
                if (value == true) {
                  _fetchAllUsers();
                  // التحقق من mounted قبل استخدام context
                  if (mounted) {
                    showCustomSnackBar(context, 'تم تحديث بيانات المستخدم بنجاح.', isSuccess: true);
                  }
                }
              });
            },
          ),
        );
      },
    );
  }

  String _translateUserStatus(String status) {
    switch (status) {
      case 'active': return 'نشط';
      case 'suspended': return 'معلق';
      case 'deleted': return 'محذوف';
      default: return status;
    }
  }
}