import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../common/support_chat_screen.dart';
import '../merchant/order_details_screen.dart';
import '../merchant/order_list_screen.dart';
import 'admin_settlement_history_screen.dart';

// تم تضمين هذه الدالة هنا لأنها كانت موجودة في الملف الذي تم تقديمه.
// إذا كانت هذه الدالة موجودة في ملف منفصل (مثل common/custom_snackbar.dart)،
// فيرجى التأكد من استيرادها بدلاً من وضعها هنا مباشرة.
void showCustomSnackBar(BuildContext context, String message, {bool isError = false, bool isSuccess = false}) {
  Color backgroundColor = const Color.fromRGBO(85, 85, 85, 1);
  IconData icon = Icons.info_outline;

  if (isError) {
    backgroundColor = Theme.of(context).colorScheme.error;
    icon = Icons.error_outline;
  } else if (isSuccess) {
    backgroundColor = Theme.of(context).colorScheme.primary;
    icon = Icons.check_circle_outline;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
              textDirection: TextDirection.rtl, // هذا التوجيه يحتاج إلى isRtl
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ),
  );
}

// تم تضمين هذه الدالة هنا لنفس السبب.
// إذا كانت هذه الدالة موجودة في ملف منفصل، فيرجى التأكد من استيرادها.
Future<void> sendNotificationToAdmins(
    FirebaseFirestore firestore,
    String title,
    String body, {
    String type = 'general_info',
    String? relatedOrderId,
    String? relatedSettlementId,
    String? senderId,
    String? senderName,
}) async {
  try {
    QuerySnapshot adminUsersSnapshot = await firestore
        .collection('users')
        .where('userType', isEqualTo: 'admin')
        .get();

    WriteBatch batch = firestore.batch();
    for (var doc in adminUsersSnapshot.docs) {
      batch.set(firestore.collection('notifications').doc(), {
        'userId': doc.id,
        'userTypeTarget': 'admin',
        'title': title,
        'body': body,
        'type': type,
        'relatedOrderId': relatedOrderId,
        'relatedSettlementId': relatedSettlementId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'senderId': senderId,
        'senderName': senderName,
      });
    }
    await batch.commit();
    debugPrint("Notification sent to all admins: $title");
  } on FirebaseException catch (e) {
    debugPrint("Firebase Error sending notification to admins: ${e.message}");
  } catch (e) {
    debugPrint("General Error sending notification to admins: $e"); // إزالة الأقواس
  }
}


class AdminUserProfileScreen extends StatefulWidget {
  final String userId;
  const AdminUserProfileScreen({super.key, required this.userId});

  @override
  State<AdminUserProfileScreen> createState() => _AdminUserProfileScreenState();
}

class _AdminUserProfileScreenState extends State<AdminUserProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _whatsappNumberController = TextEditingController();
  final TextEditingController _personalPhoneController = TextEditingController();
  final TextEditingController _pickupAddressController = TextEditingController();
  final TextEditingController _homeAddressController = TextEditingController();

  DateTime? _dateOfBirth;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _userType;
  String? _userStatus;
  String? _suspensionReason;
  String? _userNameForChat;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _storeNameController.dispose();
    _whatsappNumberController.dispose();
    _personalPhoneController.dispose();
    _pickupAddressController.dispose();
    _homeAddressController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    if (!mounted) return;

    try {
      final DocumentSnapshot userDoc = await _firestore.collection('users').doc(widget.userId).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _userType = userDoc['userType'] as String?;
          _userStatus = userDoc['status'] as String? ?? 'active';
          _suspensionReason = userDoc['suspension_reason'] as String?;

          _nameController.text = userDoc['name'] as String? ?? '';
          _phoneController.text = userDoc['phone'] as String? ?? '';
          _emailController.text = userDoc['email'] as String? ?? '';
          _userNameForChat = userDoc['name'] as String? ?? userDoc['storeName'] as String? ?? 'مستخدم غير معروف';

          if (userDoc['dateOfBirth'] != null) {
            _dateOfBirth = (userDoc['dateOfBirth'] as Timestamp).toDate();
          }

          if (_userType == 'merchant') {
            _storeNameController.text = userDoc['storeName'] as String? ?? '';
            _whatsappNumberController.text = userDoc['whatsappNumber'] as String? ?? '';
            _personalPhoneController.text = userDoc['personalPhone'] as String? ?? '';
            _pickupAddressController.text = userDoc['pickupAddress'] as String? ?? '';
          } else if (_userType == 'driver') {
            _homeAddressController.text = userDoc['homeAddress'] as String? ?? '';
          }
          _isLoading = false;
        });
      } else if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isLoading = false; });
        showCustomSnackBar(context, 'لم يتم العثور على بيانات المستخدم.', isError: true);
      }
    } catch (e) {
      debugPrint("Error fetching user profile (Admin): $e"); // إزالة الأقواس
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isLoading = false; });
        showCustomSnackBar(context, 'حدث خطأ عند جلب بيانات المستخدم.', isError: true);
      }
    }
  }

  Future<void> _updateUserProfile() async {
    if (!mounted) return;
    setState(() { _isSaving = true; });

    try {
      final Map<String, dynamic> updatedData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'dateOfBirth': _dateOfBirth != null ? Timestamp.fromDate(_dateOfBirth!) : null,
      };

      if (_userType == 'merchant') {
        updatedData['storeName'] = _storeNameController.text.trim();
        updatedData['whatsappNumber'] = _whatsappNumberController.text.trim();
        updatedData['personalPhone'] = _personalPhoneController.text.trim();
        updatedData['pickupAddress'] = _pickupAddressController.text.trim();
      } else if (_userType == 'driver') {
        updatedData['homeAddress'] = _homeAddressController.text.trim();
      }

      await _firestore.collection('users').doc(widget.userId).update(updatedData);
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'تم تحديث الملف الشخصي بنجاح!', isSuccess: true);
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error updating user profile: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ في Firebase: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("General Error updating user profile: $e"); // إزالة الأقواس
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ غير متوقع عند تحديث الملف الشخصي.', isError: true);
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final ThemeData theme = Theme.of(context);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
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
    if (picked != null && picked != _dateOfBirth && mounted) { // التحقق من mounted
      setState(() => _dateOfBirth = picked);
    }
  }

  void _showSuspendConfirmDialog() {
    final TextEditingController reasonController = TextEditingController();
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // تحديد اتجاه النص

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(
          "تأكيد تعليق الحساب",
          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(color: Theme.of(ctx).colorScheme.onSurface),
          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // استخدام isRtl
          children: [
            Text(
              "هل أنت متأكد من تعليق هذا الحساب؟",
              style: Theme.of(ctx).textTheme.bodyMedium,
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: "سبب التعليق (اختياري)",
                alignLabelWithHint: true,
                filled: Theme.of(ctx).inputDecorationTheme.filled,
                fillColor: Theme.of(ctx).inputDecorationTheme.fillColor,
                border: Theme.of(ctx).inputDecorationTheme.border,
                enabledBorder: Theme.of(ctx).inputDecorationTheme.enabledBorder,
                focusedBorder: Theme.of(ctx).inputDecorationTheme.focusedBorder,
                labelStyle: Theme.of(ctx).inputDecorationTheme.labelStyle,
                hintStyle: Theme.of(ctx).inputDecorationTheme.hintStyle,
                contentPadding: Theme.of(ctx).inputDecorationTheme.contentPadding,
              ),
              maxLines: 3,
              style: Theme.of(ctx).textTheme.bodyMedium,
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("إلغاء", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Theme.of(ctx).colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _toggleUserStatus('suspended', reason: reasonController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.secondary),
            child: Text("تعليق", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showActivateConfirmDialog() {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // تحديد اتجاه النص
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(
          "تأكيد تفعيل الحساب",
          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(color: Theme.of(ctx).colorScheme.onSurface),
          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        ),
        content: Text(
          "هل أنت متأكد من تفعيل هذا الحساب؟",
          style: Theme.of(ctx).textTheme.bodyMedium,
          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("إلغاء", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Theme.of(ctx).colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _toggleUserStatus('active');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.primary),
            child: Text("تفعيل", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog() {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // تحديد اتجاه النص
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(
          "تأكيد حذف الحساب",
          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(color: Theme.of(ctx).colorScheme.onSurface),
          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        ),
        content: Text(
          "هل أنت متأكد من حذف هذا الحساب نهائياً؟ لا يمكن التراجع عن هذا الإجراء.",
          style: Theme.of(ctx).textTheme.bodyMedium,
          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("إلغاء", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Theme.of(ctx).colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _toggleUserStatus('deleted');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text("حذف", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUserStatus(String newStatus, {String? reason}) async {
    if (!mounted) return;
    setState(() { _isSaving = true; });

    try {
      await _firestore.collection('users').doc(widget.userId).update({
        'status': newStatus,
        'suspension_reason': newStatus == 'suspended' ? reason : null,
        'status_changed_at': Timestamp.now(),
        'status_changed_by_admin': _auth.currentUser?.uid,
      });

      await _firestore.collection('notifications').add({
        'userId': widget.userId,
        'title': newStatus == 'suspended' ? 'حسابك معلق' : newStatus == 'deleted' ? 'حسابك محذوف' : 'تم تفعيل حسابك',
        // إزالة الأقواس غير الضرورية
        'body': newStatus == 'suspended' ? reason ?? 'تم تعليق حسابك.' : 'يرجى التواصل مع الإدارة للمساعدة.',
        'type': 'account_status_changed',
        'relatedOrderId': null,
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      // إزالة الأقواس غير الضرورية
      await sendNotificationToAdmins(
        _firestore,
        'تغيير حالة حساب مستخدم',
        'المسؤول ${_auth.currentUser?.email ?? _auth.currentUser?.uid} قام بتغيير حالة حساب ${_userNameForChat ?? widget.userId} إلى ${_translateSettlementStatus(newStatus)}.',
        type: 'user_status_changed_by_admin',
        senderId: _auth.currentUser?.uid,
        senderName: 'المسؤول',
      );

      await _firestore.collection('admin_logs').add({
        'adminId': _auth.currentUser?.uid,
        'actionType': 'user_status_change',
        'targetUserId': widget.userId,
        'newStatus': newStatus,
        'reason': reason,
        'timestamp': Timestamp.now(),
      });

      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() {
          _userStatus = newStatus;
          _suspensionReason = newStatus == 'suspended' ? reason : null;
          _isSaving = false;
        });
        showCustomSnackBar(context, 'تم تحديث حالة الحساب إلى ${_translateSettlementStatus(newStatus)} بنجاح!', isSuccess: true);
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error changing user status: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isSaving = false; });
        showCustomSnackBar(context, 'حدث خطأ في Firebase: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("General Error changing user status: $e"); // إزالة الأقواس
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isSaving = false; });
        showCustomSnackBar(context, 'حدث خطأ غير متوقع.', isError: true);
      }
    }
  }

  String _translateSettlementStatus(String status) {
    switch (status) {
      case 'pending_admin_approval': return 'بانتظار الموافقة';
      case 'approved': return 'تم الموافقة';
      case 'paid': return 'تم الدفع';
      case 'rejected': return 'مرفوض';
      case 'active': return 'نشط';
      case 'suspended': return 'معلق';
      case 'deleted': return 'محذوف';
      default: return status;
    }
  }

  Widget _buildProfileSectionHeader(String title) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // تحديد اتجاه النص
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
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

  // تم تعديل تعريف الدالة لقبول المعلمات المُسماة
  Widget _buildTextFormField({
      required TextEditingController controller, // تم إضافة required
      required String label, // تم إضافة required
      bool readOnly = false,
      String? Function(String?)? validator,
      TextInputType keyboardType = TextInputType.text,
      int maxLines = 1,
      }) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // تحديد اتجاه النص
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: Theme.of(context).inputDecorationTheme.filled,
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
          border: Theme.of(context).inputDecorationTheme.border,
          enabledBorder: Theme.of(context).inputDecorationTheme.enabledBorder,
          focusedBorder: Theme.of(context).inputDecorationTheme.focusedBorder,
          labelStyle: Theme.of(context).inputDecorationTheme.labelStyle,
          hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
          contentPadding: Theme.of(context).inputDecorationTheme.contentPadding,
        ),
        validator: validator,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
      ),
    );
  }

  // تم تعديل تعريف الدالة لقبول المعلمات المُسماة
  Widget _buildPhoneFormField({
      required TextEditingController controller, // تم إضافة required
      required String label, // تم إضافة required
      bool isRequired = false,
      bool readOnly = false
      }) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // تحديد اتجاه النص
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.phone,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.phone, color: Theme.of(context).colorScheme.primary),
          filled: Theme.of(context).inputDecorationTheme.filled,
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
          border: Theme.of(context).inputDecorationTheme.border,
          enabledBorder: Theme.of(context).inputDecorationTheme.enabledBorder,
          focusedBorder: Theme.of(context).inputDecorationTheme.focusedBorder,
          labelStyle: Theme.of(context).inputDecorationTheme.labelStyle,
          hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
          contentPadding: Theme.of(context).inputDecorationTheme.contentPadding,
        ),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'الرجاء إدخال رقم الهاتف';
          }
          if (value != null && value.isNotEmpty && !RegExp(r'^[0-9]+$').hasMatch(value)) {
            return 'الرجاء إدخال أرقام فقط';
          }
          return null;
        },
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // تحديد اتجاه النص مرة واحدة

    if (_userType == null || _isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text("ملف المستخدم", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "ملف ${_userType == 'merchant' ? 'التاجر' : _userType == 'driver' ? 'المندوب' : 'المسؤول'}",
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileSectionHeader("معلومات عامة"),
            _buildTextFormField(controller: _nameController, label: 'الاسم', readOnly: _isSaving),
            _buildTextFormField(controller: _emailController, label: 'البريد الإلكتروني', readOnly: true, keyboardType: TextInputType.emailAddress),
            _buildPhoneFormField(controller: _phoneController, label: 'رقم الهاتف', isRequired: true, readOnly: _isSaving),

            if (_userType == 'merchant') ...[
              _buildProfileSectionHeader("معلومات المتجر"),
              _buildTextFormField(controller: _storeNameController, label: 'اسم المتجر', readOnly: _isSaving),
              _buildPhoneFormField(controller: _whatsappNumberController, label: 'رقم الواتساب', isRequired: true, readOnly: _isSaving),
              _buildTextFormField(controller: _personalPhoneController, label: 'رقم هاتف شخصي (اختياري)', readOnly: _isSaving, keyboardType: TextInputType.phone),
              _buildTextFormField(controller: _pickupAddressController, label: 'عنوان الاستلام', readOnly: _isSaving),
            ],
            if (_userType == 'driver') ...[
              _buildProfileSectionHeader("عنوان المنزل"),
              _buildTextFormField(controller: _homeAddressController, label: 'عنوان المنزل', readOnly: _isSaving),
            ],

            _buildProfileSectionHeader("تاريخ الميلاد"),
            GestureDetector(
              onTap: _isSaving ? null : () => _selectDateOfBirth(context),
              child: AbsorbPointer(
                // تم تعديل استدعاء _buildTextFormField ليتوافق مع المعلمات المُسماة
                child: _buildTextFormField(
                  controller: TextEditingController(text: _dateOfBirth == null ? '' : DateFormat('yyyy-MM-dd').format(_dateOfBirth!)),
                  label: 'تاريخ الميلاد',
                  readOnly: true,
                ),
              ),
            ),

            const SizedBox(height: 24.0),
            _isSaving
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : ElevatedButton(
              onPressed: _updateUserProfile,
              // The 'child' argument should be last in widget constructor invocations.
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
              child: Text(
                'حفظ التعديلات',
                style: textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary),
              ),
            ),

            _buildProfileSectionHeader("تحكم إداري"),
            if (_userStatus == 'suspended')
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  // إزالة الأقواس غير الضرورية
                  'الحساب معلق. السبب: ${_suspensionReason ?? 'غير مذكور'}',
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _userStatus == 'suspended' ? _showActivateConfirmDialog : _showSuspendConfirmDialog,
                    icon: Icon(
                      _userStatus == 'suspended' ? Icons.play_arrow : Icons.pause,
                      color: Colors.white,
                    ),
                    label: FittedBox(
                      child: Text(
                        _userStatus == 'suspended' ? 'تفعيل الحساب' : 'تعليق الحساب',
                        style: textTheme.labelLarge?.copyWith(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _userStatus == 'suspended' ? colorScheme.primary : colorScheme.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _userStatus == 'deleted' ? null : _showDeleteConfirmDialog,
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: FittedBox(
                      child: Text('حذف الحساب', style: textTheme.labelLarge?.copyWith(color: Colors.white)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SupportChatScreen(
                        targetUserId: widget.userId,
                        targetUserName: _userNameForChat,
                      )
                  ),
                );
              },
              icon: Icon(Icons.chat, color: colorScheme.onPrimary),
              label: Text('تواصل مع المستخدم', style: textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
            ),

            _buildProfileSectionHeader("طلبات المستخدم"),
            SizedBox(
              height: 220,
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('orders')
                    .where(_userType == 'merchant' ? 'merchantId' : 'driverId', isEqualTo: widget.userId)
                    .orderBy('createdAt', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                  }
                  if (snapshot.hasError) {
                    debugPrint("User Orders Stream Error: ${snapshot.error}");
                    return Center(
                        child: Text(
                            // إزالة الأقواس غير الضرورية
                            'حدث خطأ: ${snapshot.error}',
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.error)
                        )
                    );
                  }
                  if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long, size: 60, color: Color.fromRGBO(189, 189, 189, 1)),
                          const SizedBox(height: 8),
                          Text(
                            'لا توجد طلبات لهذا المستخدم حالياً.',
                            style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final DocumentSnapshot orderDoc = snapshot.data!.docs[index];
                      final String orderStatus = orderDoc['status'] as String? ?? 'غير معروف';
                      final Color statusColor = _getStatusColorForOrder(orderStatus, colorScheme);

                      return Card(
                        elevation: cardTheme.elevation,
                        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                        shape: cardTheme.shape,
                        color: cardTheme.color,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          title: Text(
                            'طلب رقم: #${orderDoc['orderNumber'] ?? orderDoc.id}',
                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                          ),
                          subtitle: Text(
                            'الحالة: ${_translateSettlementStatus(orderStatus)} - ${DateFormat('yyyy-MM-dd').format((orderDoc['createdAt'] as Timestamp).toDate())}',
                            style: textTheme.bodySmall?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // استخدام isRtl
                            children: [
                              Text(
                                '${orderDoc['totalPrice']?.toStringAsFixed(0) ?? '0'} د.ع',
                                style: textTheme.titleSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                              ),
                              if (orderStatus == 'reported')
                                Icon(Icons.warning_amber, color: colorScheme.error, size: 18),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => OrderDetailsScreen(orderId: orderDoc.id)
                                )
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => OrderListScreen(
                          status: 'all',
                          title: 'طلبات المستخدم',
                          userId: widget.userId,
                          userType: _userType!
                      )
                  ),
                );
              },
              child: Text('عرض جميع الطلبات', style: textTheme.labelLarge?.copyWith(color: colorScheme.primary)),
            ),

            _buildProfileSectionHeader("سجل التحاسب"),
            SizedBox(
              height: 220,
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('settlements')
                    .where('userId', isEqualTo: widget.userId)
                    .orderBy('date', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                  }
                  if (snapshot.hasError) {
                    debugPrint("Settlement Stream Error: ${snapshot.error}");
                    return Center(
                        child: Text(
                            // إزالة الأقواس غير الضرورية
                            'حدث خطأ: ${snapshot.error}',
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.error)
                        )
                    );
                  }
                  if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.account_balance_wallet, size: 60, color: Color.fromRGBO(189, 189, 189, 1)),
                          const SizedBox(height: 8),
                          Text(
                            'لا توجد سجلات تحاسب لهذا المستخدم حالياً.',
                            style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final DocumentSnapshot settlementDoc = snapshot.data!.docs[index];
                      final DateTime settlementDate = (settlementDoc['date'] as Timestamp).toDate();
                      final String settlementStatus = settlementDoc['status'] as String? ?? 'غير معروف';
                      final bool isSettled = settlementStatus == 'paid' || settlementStatus == 'approved';
                      final bool isPending = settlementStatus == 'pending_admin_approval';

                      return Card(
                        elevation: cardTheme.elevation,
                        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                        shape: cardTheme.shape,
                        color: cardTheme.color,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          title: Text(
                            'تحاسب بتاريخ: ${DateFormat('yyyy-MM-dd').format(settlementDate)}',
                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                          ),
                          subtitle: Text(
                            'المبلغ: ${settlementDoc['totalAmount']?.toStringAsFixed(0) ?? '0'} د.ع | الحالة: ${_translateSettlementStatus(settlementStatus)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: isPending ? colorScheme.secondary : (isSettled ? colorScheme.primary : colorScheme.error),
                            ),
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                          ),
                          trailing: isPending ? Icon(Icons.warning_amber, color: colorScheme.secondary, size: 18) : null,
                          onTap: () {
                            if (mounted) { // التحقق من mounted قبل استخدام context
                                showCustomSnackBar(context, 'تفاصيل التحاسب بتاريخ: ${DateFormat('yyyy-MM-dd').format(settlementDate)}', isSuccess: true);
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AdminSettlementHistoryScreen(
                          userId: widget.userId,
                          userType: _userType!
                      )
                  ),
                );
              },
              child: Text('عرض جميع سجلات التحاسب', style: textTheme.labelLarge?.copyWith(color: colorScheme.primary)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColorForOrder(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'delivered': return colorScheme.primary;
      case 'reported': return colorScheme.error;
      case 'cancelled': return Colors.grey;
      default: return colorScheme.onSurface;
    }
  }
}